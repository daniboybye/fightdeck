package com.fightdeck.swiftcore.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.fightevents.EventCatalogBridge
import com.fightdeck.fightevents.MediaItem
import com.fightdeck.fightevents.NewsItem
import com.fightdeck.swiftcore.bridge.SwiftCoreBridge
import com.fightdeck.swiftcore.catalog.BoutCard
import com.fightdeck.swiftcore.catalog.CardSectionCard
import com.fightdeck.swiftcore.catalog.EventCard
import com.fightdeck.swiftcore.catalog.FighterCard
import com.fightdeck.swiftcore.catalog.boutCard
import com.fightdeck.swiftcore.catalog.cardSections
import com.fightdeck.swiftcore.catalog.fighterCard
import com.fightdeck.swiftcore.catalog.loadEvents
import com.fightdeck.fightslip.SlipEngine
import com.fightdeck.swiftcore.core.SlipSnapshot
import com.fightdeck.swiftcore.core.readSnapshot
import com.fightdeck.swiftcore.services.DatasetLocator
import com.fightdeck.swiftcore.services.LocalAssetServer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private var catalog: EventCatalogBridge? = null

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    init {
        check(SwiftCoreBridge.verifyNativeCore() == "€361.11") {
            "libfightcore.so did not answer through JNI"
        }
        bootstrap()
    }

    private val _events = MutableStateFlow<LoadState<List<EventCard>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventCard>>> = _events.asStateFlow()

    private var slipEngine: SlipEngine? = null

    // Null only until bootstrap has made the engine; the tabs are not composed before then.
    // Every write goes through publishSlip, straight from the engine, so nothing on this side
    // holds a second copy of the slip, the balance or the confirmation.
    private val _slip = MutableStateFlow<SlipSnapshot?>(null)
    val slip: StateFlow<SlipSnapshot?> = _slip.asStateFlow()

    private val _news = MutableStateFlow<LoadState<List<NewsItem>>>(LoadState.Loading)
    val news: StateFlow<LoadState<List<NewsItem>>> = _news.asStateFlow()

    private val _media = MutableStateFlow<LoadState<List<MediaItem>>>(LoadState.Loading)
    val media: StateFlow<LoadState<List<MediaItem>>> = _media.asStateFlow()

    private fun updateSlip(change: SlipEngine.() -> Unit) {
        val engine = requireNotNull(slipEngine)
        engine.change()
        _slip.value = engine.readSnapshot()
    }

    fun retryBootstrap() {
        bootstrap()
    }

    private fun bootstrap() {
        viewModelScope.launch {
            _bootstrapState.value = BootstrapState.Loading("Loading fight core…")
            val booted = withContext(Dispatchers.Default) {
                runCatching { bootstrapEngine(getApplication()) }
            }
            booted.fold(
                onSuccess = { loaded ->
                    catalog = loaded
                    slipEngine = SlipEngine.`init`(loaded.boutIndexJSON)
                    updateSlip {}
                    _bootstrapState.value = BootstrapState.Ready
                    refreshEvents()
                    refreshNews()
                    refreshMedia()
                },
                onFailure = { error ->
                    _bootstrapState.value = BootstrapState.Failed(
                        error.message ?: "Could not load dataset",
                    )
                },
            )
        }
    }

    private fun bootstrapEngine(application: Application): EventCatalogBridge {
        val root = DatasetLocator.datasetRoot(application)
        LocalAssetServer.start(root)
        // jextract exposes Swift initialisers as a static `init`, which Kotlin reads as a
        // keyword and needs escaped.
        return EventCatalogBridge.`init`(root.path)
    }

    fun refreshEvents() {
        _events.value = loadState("Could not load events") { requireNotNull(catalog).loadEvents() }
    }

    fun cardSections(eventID: String): List<CardSectionCard> =
        requireNotNull(catalog).cardSections(eventID)

    fun bout(boutID: String): BoutCard = requireNotNull(catalog).boutCard(boutID)

    fun fighter(id: String): FighterCard? =
        runCatching { requireNotNull(catalog).fighterCard(id) }.getOrNull()

    fun taleOfTheTape(boutID: String) = requireNotNull(catalog).taleOfTheTape(boutID)

    fun legContext(boutID: String, fighterID: String) =
        requireNotNull(catalog).legContext(boutID, fighterID)

    fun refreshNews() {
        _news.value = loadState("Could not load news") { requireNotNull(catalog).news().toList() }
    }

    fun refreshMedia() {
        _media.value = loadState("Could not load media") { requireNotNull(catalog).media().toList() }
    }

    private fun <T> loadState(error: String, load: () -> List<T>): LoadState<List<T>> =
        runCatching(load).fold(
            onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
            onFailure = { LoadState.Error(error) },
        )

    fun imageUrl(path: String): String? =
        LocalAssetServer.port.takeIf { it > 0 }?.let { "http://127.0.0.1:$it/$path" }

    // Amounts and odds go over as the text they arrived in; the core parses them.
    fun toggleSelection(boutID: String, fighterId: String, odds: String) =
        updateSlip { toggleSelection(boutID, fighterId, odds) }

    fun updateStake(stake: String) = updateSlip { updateStake(stake) }

    fun removeSelection(boutId: String, fighterId: String) =
        updateSlip { removeSelection(boutId, fighterId) }

    fun placeBet() = updateSlip { placeBet() }

    fun deposit(amount: String) = updateSlip { deposit(amount) }
}
