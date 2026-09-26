package com.fightdeck.swiftcore.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.sdk.EventCatalogBridge
import com.fightdeck.sdk.FightDeckJava
import com.fightdeck.sdk.SlipEngine
import com.fightdeck.swiftcore.bridge.SwiftCoreBridge
import com.fightdeck.swiftcore.catalog.BoutCard
import com.fightdeck.swiftcore.catalog.CardSectionCard
import com.fightdeck.swiftcore.catalog.EventCard
import com.fightdeck.swiftcore.catalog.FighterCard
import com.fightdeck.swiftcore.catalog.LegContext
import com.fightdeck.swiftcore.catalog.MediaItem
import com.fightdeck.swiftcore.catalog.NewsItem
import com.fightdeck.swiftcore.catalog.TapeRowCard
import com.fightdeck.swiftcore.catalog.boutCard
import com.fightdeck.swiftcore.catalog.eventCards
import com.fightdeck.swiftcore.catalog.fighterCard
import com.fightdeck.swiftcore.catalog.legContextCard
import com.fightdeck.swiftcore.catalog.mediaItems
import com.fightdeck.swiftcore.catalog.newsItems
import com.fightdeck.swiftcore.catalog.sectionCards
import com.fightdeck.swiftcore.catalog.tapeRows
import com.fightdeck.swiftcore.core.SlipSnapshot
import com.fightdeck.swiftcore.core.readSnapshot
import com.fightdeck.swiftcore.services.DatasetLocator
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

    /** `http://127.0.0.1:<port>/`, once the core's image server is up. */
    @Volatile
    private var assetBase: String? = null

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    init {
        check(SwiftCoreBridge.verifyNativeCore() == "€361.11") {
            "libfightdeck.so did not answer through JNI"
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
                    slipEngine = SlipEngine.`init`(loaded)
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
        assetBase = FightDeckJava.startAssetServer(root.path)
        // jextract exposes Swift initialisers as a static `init`, which Kotlin reads as a
        // keyword and needs escaped.
        return EventCatalogBridge.`init`(root.path)
    }

    fun refreshEvents() {
        _events.value = loadState("Could not load events") { requireNotNull(catalog).eventCards() }
    }

    // Each of these crosses once per call and returns plain values; the screens remember the
    // result per id rather than asking again on every recomposition.
    fun cardSections(eventID: String): List<CardSectionCard> =
        requireNotNull(catalog).sectionCards(eventID)

    fun bout(boutID: String): BoutCard = requireNotNull(catalog).boutCard(boutID)

    fun fighter(id: String): FighterCard? =
        runCatching { requireNotNull(catalog).fighterCard(id) }.getOrNull()

    fun taleOfTheTape(boutID: String): List<TapeRowCard> = requireNotNull(catalog).tapeRows(boutID)

    fun legContext(boutID: String, fighterID: String): LegContext =
        requireNotNull(catalog).legContextCard(boutID, fighterID)

    fun refreshNews() {
        _news.value = loadState("Could not load news") { requireNotNull(catalog).newsItems() }
    }

    fun refreshMedia() {
        _media.value = loadState("Could not load media") { requireNotNull(catalog).mediaItems() }
    }

    private fun <T> loadState(error: String, load: () -> List<T>): LoadState<List<T>> =
        runCatching(load).fold(
            onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
            onFailure = { LoadState.Error(error) },
        )

    fun imageUrl(path: String): String? = assetBase?.let { it + path }

    // Amounts and odds go over as the text they arrived in; the core parses them.
    fun toggleSelection(boutID: String, fighterId: String, odds: String) =
        updateSlip { toggleSelection(boutID, fighterId, odds) }

    fun updateStake(stake: String) = updateSlip { updateStake(stake) }

    fun removeSelection(boutId: String, fighterId: String) =
        updateSlip { removeSelection(boutId, fighterId) }

    fun placeBet() = updateSlip { placeBet() }

    fun deposit(amount: String) = updateSlip { deposit(amount) }
}
