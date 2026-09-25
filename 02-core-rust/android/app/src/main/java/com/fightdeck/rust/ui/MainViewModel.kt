package com.fightdeck.rust.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.rust.core.StateFlowBetSlipStore
import com.fightdeck.rust.services.DatasetLocator
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
import uniffi.fightevents.MediaItem
import uniffi.fightevents.NewsItem
import uniffi.fightevents.assetUrl
import uniffi.fightevents.startAssetServer
import uniffi.fightslip.BoutIndexRecord
import uniffi.fightslip.SlipHandle
import uniffi.fightslip.SlipSnapshot

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
    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    private val _engine = MutableStateFlow<RustEngine?>(null)

    private val _events = MutableStateFlow<LoadState<List<EventSummary>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventSummary>>> = _events.asStateFlow()

    private val _news = MutableStateFlow<LoadState<List<NewsItem>>>(LoadState.Loading)
    val news: StateFlow<LoadState<List<NewsItem>>> = _news.asStateFlow()

    private val _media = MutableStateFlow<LoadState<List<MediaItem>>>(LoadState.Loading)
    val media: StateFlow<LoadState<List<MediaItem>>> = _media.asStateFlow()

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
                    _engine.value = engine
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

    val snapshot: StateFlow<SlipSnapshot>
        get() = requireSlipStore().snapshot

    fun refreshEvents() {
        _events.value = loadState("Could not load events") { requireCatalog().events() }
    }

    fun refreshNews() {
        _news.value = loadState("Could not load news") { requireCatalog().news() }
    }

    fun refreshMedia() {
        _media.value = loadState("Could not load media") { requireCatalog().media() }
    }

    private fun <T> loadState(error: String, load: () -> List<T>): LoadState<List<T>> =
        runCatching(load).fold(
            onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
            onFailure = { LoadState.Error(error) },
        )

    fun imageUrl(path: String): String? = assetUrl(path)

    fun toggleSelection(bout: BoutSummary, fighterId: String, odds: String) {
        requireSlipStore().toggleSelection(bout.id, fighterId, odds)
    }

    fun updateStake(stake: String) {
        requireSlipStore().setStake(stake)
    }

    fun removeSelection(boutId: String, fighterId: String) {
        requireSlipStore().removeSelection(boutId, fighterId)
    }

    fun placeBet() {
        requireSlipStore().placeBet()
    }

    fun deposit(amount: String) {
        requireSlipStore().deposit(amount)
    }

    override fun onCleared() {
        _engine.value?.slipStore?.close()
        _engine.value?.slip?.close()
        _engine.value?.catalog?.close()
        super.onCleared()
    }

    private companion object {
        private const val TAG = "FightDeckRustBoot"

        private fun bootstrapRustEngine(
            application: Application,
            onStep: (String) -> Unit,
        ): RustEngine {
            Log.i(TAG, "bootstrapRustEngine start")
            onStep("Loading fight catalogue…")
            val root = DatasetLocator.datasetRoot(application).path
            startAssetServer(root)
            val catalog = EventCatalog.load(root)
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
            return RustEngine(catalog, slip, slipStore)
        }
    }
}
