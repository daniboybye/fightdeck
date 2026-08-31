package com.fightdeck.rust.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.rust.core.FightCoreDisplay
import com.fightdeck.rust.core.StateFlowBetSlipStore
import uniffi.fightcore.validationErrorCode
import com.fightdeck.rust.data.BoutItem
import com.fightdeck.rust.data.EventItem
import com.fightdeck.rust.data.FighterItem
import com.fightdeck.rust.data.JsonFileRepository
import com.fightdeck.rust.data.MediaItem
import com.fightdeck.rust.data.NewsItem
import com.fightdeck.rust.services.DatasetLocator
import com.fightdeck.rust.services.LocalAssetServer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import uniffi.fightcore.BetSlipRecord
import uniffi.fightcore.BoutIndexRecord
import uniffi.fightcore.FightCoreHandle
import uniffi.fightcore.SlipStateRecord

sealed interface LoadState<out T> {
    data object Loading : LoadState<Nothing>
    data class Loaded<T>(val value: T) : LoadState<T>
    data object Empty : LoadState<Nothing>
    data class Error(val message: String) : LoadState<Nothing>
}

sealed interface BootstrapState {
    data class Loading(val step: String) : BootstrapState
    data class Failed(val message: String) : BootstrapState
    data object Ready : BootstrapState
}

/** Rust core + slip store; available after background bootstrap completes. */
data class RustEngine(
    val core: FightCoreHandle,
    val slipStore: StateFlowBetSlipStore,
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private var repository: JsonFileRepository? = null

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    private val _engine = MutableStateFlow<RustEngine?>(null)
    val engine: StateFlow<RustEngine?> = _engine.asStateFlow()

    private val _events = MutableStateFlow<LoadState<List<EventItem>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventItem>>> = _events.asStateFlow()

    private val _fighters = MutableStateFlow<LoadState<List<FighterItem>>>(LoadState.Loading)
    val fighters: StateFlow<LoadState<List<FighterItem>>> = _fighters.asStateFlow()

    private val _news = MutableStateFlow<LoadState<List<NewsItem>>>(LoadState.Loading)
    val news: StateFlow<LoadState<List<NewsItem>>> = _news.asStateFlow()

    private val _media = MutableStateFlow<LoadState<List<MediaItem>>>(LoadState.Loading)
    val media: StateFlow<LoadState<List<MediaItem>>> = _media.asStateFlow()

    private val _betPlacedMessage = MutableStateFlow<String?>(null)
    val betPlacedMessage: StateFlow<String?> = _betPlacedMessage.asStateFlow()

    init {
        bootstrap()
    }

    fun retryBootstrap() {
        bootstrap()
    }

    private fun bootstrap() {
        viewModelScope.launch {
            _engine.value?.slipStore?.close()
            _engine.value?.core?.close()
            _engine.value = null
            _bootstrapState.value = BootstrapState.Loading("Loading fight core…")
            val booted = withContext(Dispatchers.Default) {
                runCatching { bootstrapRustEngine(getApplication()) { step ->
                    _bootstrapState.value = BootstrapState.Loading(step)
                } }
            }
            booted.fold(
                onSuccess = { engine ->
                    repository = JsonFileRepository(engine.datasetRoot)
                    _engine.value = engine.rustEngine
                    _bootstrapState.value = BootstrapState.Ready
                    refreshEvents()
                    refreshFighters()
                    refreshNews()
                    refreshMedia()
                },
                onFailure = { error ->
                    Log.e(TAG, "Rust bootstrap failed", error)
                    _bootstrapState.value = BootstrapState.Failed(
                        error.message ?: "Could not start fight core",
                    )
                },
            )
        }
    }

    private fun requireSlipStore(): StateFlowBetSlipStore =
        requireNotNull(_engine.value?.slipStore) { "Rust engine not ready" }

    val slip: StateFlow<BetSlipRecord>
        get() = requireSlipStore().slip

    val slipState: StateFlow<SlipStateRecord>
        get() = requireSlipStore().slipState

    val balance: StateFlow<String>
        get() = requireSlipStore().balance

    fun refreshEvents() {
        viewModelScope.launch {
            _events.value = LoadState.Loading
            _events.value = runCatching { requireNotNull(repository).loadEvents() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load events") },
                )
        }
    }

    fun refreshFighters() {
        viewModelScope.launch {
            _fighters.value = LoadState.Loading
            _fighters.value = runCatching { requireNotNull(repository).loadFighters() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load fighters") },
                )
        }
    }

    fun refreshNews() {
        viewModelScope.launch {
            _news.value = LoadState.Loading
            _news.value = runCatching { requireNotNull(repository).loadNews() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load news") },
                )
        }
    }

    fun refreshMedia() {
        viewModelScope.launch {
            _media.value = LoadState.Loading
            _media.value = runCatching { requireNotNull(repository).loadMedia() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load media") },
                )
        }
    }

    fun imageUrl(path: String): String? = repository?.imageUrl(path)

    fun toggleSelection(bout: BoutItem, fighterId: String, odds: String) {
        requireSlipStore().toggleSelection(bout.id, fighterId, odds)
        _betPlacedMessage.value = null
    }

    fun isSelected(boutId: String, fighterId: String): Boolean =
        requireSlipStore().isSelected(boutId, fighterId)

    fun updateStake(stake: String) {
        requireSlipStore().setStake(stake)
    }

    fun removeSelection(boutId: String, fighterId: String) {
        requireSlipStore().removeSelection(boutId, fighterId)
        _betPlacedMessage.value = null
    }

    fun placeBet() {
        val state = requireSlipStore().placeBet() ?: return
        _betPlacedMessage.value =
            "${FightCoreDisplay.formatCurrencyAmount(state.potentialReturn)} returns if it lands"
    }

    fun deposit(amount: String) {
        requireSlipStore().deposit(amount)
    }

    fun slipSummary(state: SlipStateRecord) = FightCoreDisplay.slipSummary(state)

    fun formatOdds(odds: String) = FightCoreDisplay.formatOdds(odds)
    fun formatCurrency(amount: String) = FightCoreDisplay.formatCurrencyAmount(amount)
    fun errorCode(error: uniffi.fightcore.ValidationErrorRecord) = validationErrorCode(error)

    override fun onCleared() {
        _engine.value?.slipStore?.close()
        _engine.value?.core?.close()
        super.onCleared()
    }

    private data class BootstrapResult(
        val datasetRoot: java.io.File,
        val rustEngine: RustEngine,
    )

    private companion object {
        private const val TAG = "FightDeckRustBoot"

        private fun bootstrapRustEngine(
            application: Application,
            onStep: (String) -> Unit,
        ): BootstrapResult {
            Log.i(TAG, "bootstrapRustEngine start")
            onStep("Loading fight core…")
            val root = DatasetLocator.datasetRoot(application)
            LocalAssetServer.start(root)
            val core = buildFightCore(root)
            Log.i(TAG, "FightCoreHandle ready")
            onStep("Starting bet slip…")
            val slipBacking = uniffi.fightcore.BetSlipStore(core, "500.00")
            Log.i(TAG, "BetSlipStore ready")
            onStep("Preparing UI…")
            val slipStore = StateFlowBetSlipStore(slipBacking)
            Log.i(TAG, "StateFlowBetSlipStore ready")
            return BootstrapResult(root, RustEngine(core, slipStore))
        }

        private fun buildFightCore(root: java.io.File): FightCoreHandle {
            Log.i(TAG, "buildFightCore dataset=$root")
            val eventsJson = root.resolve("events.json").readText()
            val events = Json { ignoreUnknownKeys = true }
                .decodeFromString<EventsEnvelope>(eventsJson)
            val bouts = events.events.flatMap { it.bouts }.map {
                BoutIndexRecord(
                    id = it.id,
                    redFighterId = it.redCorner.fighterId,
                    blueFighterId = it.blueCorner.fighterId,
                    winnerId = it.result.winnerId,
                )
            }
            return FightCoreHandle(bouts)
        }
    }
}

@Serializable
private data class EventsEnvelope(val events: List<EventEnvelope>)

@Serializable
private data class EventEnvelope(val bouts: List<BoutEnvelope>)

@Serializable
private data class BoutEnvelope(
    val id: String,
    val redCorner: CornerEnvelope,
    val blueCorner: CornerEnvelope,
    val result: ResultEnvelope,
)

@Serializable
private data class CornerEnvelope(@SerialName("fighterId") val fighterId: String)

@Serializable
private data class ResultEnvelope(@SerialName("winnerId") val winnerId: String)
