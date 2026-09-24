package com.fightdeck.rust.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.rust.core.FightCoreDisplay
import com.fightdeck.rust.core.StateFlowBetSlipStore
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
import uniffi.fightevents.BoutSummary
import uniffi.fightevents.EventCatalog
import uniffi.fightevents.EventSummary
import uniffi.fightevents.FighterSummary
import uniffi.fightslip.BetSlipRecord
import uniffi.fightslip.BoutIndexRecord
import uniffi.fightslip.SlipHandle
import uniffi.fightslip.SlipStateRecord

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

/** The three Rust SDKs, available after background bootstrap completes. */
data class RustEngine(
    val catalog: EventCatalog,
    val slip: SlipHandle,
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

    private val _events = MutableStateFlow<LoadState<List<EventSummary>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventSummary>>> = _events.asStateFlow()

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
            _engine.value?.slip?.close()
            _engine.value?.catalog?.close()
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

    fun requireCatalog(): EventCatalog =
        requireNotNull(_engine.value?.catalog) { "Rust engine not ready" }

    fun fighter(id: String): FighterSummary? =
        runCatching { requireCatalog().fighter(id) }.getOrNull()

    val slip: StateFlow<BetSlipRecord>
        get() = requireSlipStore().slip

    val slipState: StateFlow<SlipStateRecord>
        get() = requireSlipStore().slipState

    val balance: StateFlow<String>
        get() = requireSlipStore().balance

    fun refreshEvents() {
        val events = runCatching { requireCatalog().events() }.getOrElse {
            _events.value = LoadState.Error("Could not load events")
            return
        }
        _events.value = if (events.isEmpty()) LoadState.Empty else LoadState.Loaded(events)
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

    fun toggleSelection(bout: BoutSummary, fighterId: String, odds: String) {
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
        _betPlacedMessage.value = requireSlipStore().placeBet().message
    }

    fun deposit(amount: String) {
        requireSlipStore().deposit(amount)
    }

    fun formatOdds(odds: String) = FightCoreDisplay.formatOdds(odds)
    fun formatCurrency(amount: String) = FightCoreDisplay.formatCurrencyAmount(amount)

    override fun onCleared() {
        _engine.value?.slipStore?.close()
        _engine.value?.slip?.close()
        _engine.value?.catalog?.close()
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
            onStep("Loading fight catalogue…")
            val root = DatasetLocator.datasetRoot(application)
            LocalAssetServer.start(root)
            val catalog = EventCatalog.parse(
                root.resolve("events.json").readText(),
                root.resolve("fighters.json").readText(),
            )
            Log.i(TAG, "EventCatalog ready")

            onStep("Starting bet slip…")
            val slip = SlipHandle(
                catalog.boutIndex().map {
                    BoutIndexRecord(it.id, it.redFighterId, it.blueFighterId, it.winnerId)
                },
            )
            val slipStore = StateFlowBetSlipStore(uniffi.fightslip.BetSlipStore(slip, "500.00"))
            Log.i(TAG, "BetSlipStore ready")

            onStep("Preparing UI…")
            return BootstrapResult(root, RustEngine(catalog, slip, slipStore))
        }
    }
}
