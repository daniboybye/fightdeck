package com.fightdeck.swiftcore.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.fightevents.EventCatalogBridge
import com.fightdeck.swiftcore.bridge.SharedPreferencesStore
import com.fightdeck.swiftcore.bridge.SwiftCoreBridge
import com.fightdeck.swiftcore.catalog.BoutCard
import com.fightdeck.swiftcore.catalog.CardSectionCard
import com.fightdeck.swiftcore.catalog.EventCard
import com.fightdeck.swiftcore.catalog.FighterCard
import com.fightdeck.swiftcore.catalog.boutCard
import com.fightdeck.swiftcore.catalog.cardSections
import com.fightdeck.swiftcore.catalog.fighterCard
import com.fightdeck.swiftcore.catalog.loadEvents
import com.fightdeck.swiftcore.core.BetSlip
import com.fightdeck.swiftcore.core.BetMode
import com.fightdeck.swiftcore.core.BoutIndex
import com.fightdeck.swiftcore.core.Money
import com.fightdeck.swiftcore.core.SlipState
import com.fightdeck.swiftcore.core.SwiftSlipStore
import com.fightdeck.swiftcore.data.JsonFileRepository
import com.fightdeck.swiftcore.data.MediaItem
import com.fightdeck.swiftcore.data.NewsItem
import com.fightdeck.swiftcore.services.DatasetLocator
import com.fightdeck.swiftcore.services.LocalAssetServer
import java.math.BigDecimal
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
    private val preferences = SharedPreferencesStore(application)
    private var repository: JsonFileRepository? = null
    private var catalog: EventCatalogBridge? = null

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    init {
        check(!SwiftCoreBridge.isStub) { "Expected the cross-compiled Swift core, not a stub" }
        check(SwiftCoreBridge.verifyNativeCore() == "€361.11") {
            "libfightcore.so did not answer through JNI"
        }
        preferences.write("swift_core_mode", "swift")
        bootstrap()
    }

    private val _events = MutableStateFlow<LoadState<List<EventCard>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventCard>>> = _events.asStateFlow()

    private var slipStore: SwiftSlipStore? = null

    private val _slip = MutableStateFlow(
        BetSlip(BetMode.single, emptyList(), BigDecimal("10.00")),
    )
    val slip: StateFlow<BetSlip> = _slip.asStateFlow()

    private val _balance = MutableStateFlow(BigDecimal("500.00"))
    val balance: StateFlow<BigDecimal> = _balance.asStateFlow()

    private val _news = MutableStateFlow<LoadState<List<NewsItem>>>(LoadState.Loading)
    val news: StateFlow<LoadState<List<NewsItem>>> = _news.asStateFlow()

    private val _media = MutableStateFlow<LoadState<List<MediaItem>>>(LoadState.Loading)
    val media: StateFlow<LoadState<List<MediaItem>>> = _media.asStateFlow()

    private val _betPlacedMessage = MutableStateFlow<String?>(null)
    val betPlacedMessage: StateFlow<String?> = _betPlacedMessage.asStateFlow()

    val slipState: SlipState
        get() = requireNotNull(slipStore).slipState

    private fun publishSlipState() {
        val store = requireNotNull(slipStore)
        _slip.value = store.slip
        _balance.value = store.balance
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
                onSuccess = { engine ->
                    repository = engine.repository
                    catalog = engine.catalog
                    slipStore = SwiftSlipStore(engine.bouts)
                    publishSlipState()
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

    private data class Engine(
        val repository: JsonFileRepository,
        val catalog: EventCatalogBridge,
        val bouts: List<BoutIndex>,
    )

    private fun bootstrapEngine(application: Application): Engine {
        val root = DatasetLocator.datasetRoot(application)
        LocalAssetServer.start(root)
        // jextract exposes Swift initialisers as a static `init`, which Kotlin reads as a
        // keyword and needs escaped.
        val catalog = EventCatalogBridge.`init`(
            root.resolve("events.json").readText(),
            root.resolve("fighters.json").readText(),
        )
        val bouts = catalog.boutIndexEntries.map {
            BoutIndex(it.id, it.redFighterID, it.blueFighterID, it.winnerID)
        }
        return Engine(JsonFileRepository(root), catalog, bouts)
    }

    fun refreshEvents() {
        val events = runCatching { requireNotNull(catalog).loadEvents() }.getOrElse {
            _events.value = LoadState.Error("Could not load events")
            return
        }
        _events.value = if (events.isEmpty()) LoadState.Empty else LoadState.Loaded(events)
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

    fun toggleSelection(boutID: String, fighterId: String, odds: String) {
        requireNotNull(slipStore).toggleSelection(boutID, fighterId, Money.parse(odds))
        publishSlipState()
        _betPlacedMessage.value = null
    }

    fun updateStake(stake: BigDecimal) {
        requireNotNull(slipStore).updateStake(stake)
        publishSlipState()
    }

    fun removeSelection(boutId: String, fighterId: String) {
        requireNotNull(slipStore).removeSelection(boutId, fighterId)
        publishSlipState()
        _betPlacedMessage.value = null
    }

    fun placeBet() {
        val state = requireNotNull(slipStore).placeBet() ?: return
        publishSlipState()
        _betPlacedMessage.value =
            "${Money.formatCurrency(state.potentialReturn)} returns if it lands"
    }

    fun deposit(amount: BigDecimal) {
        requireNotNull(slipStore).deposit(amount)
        publishSlipState()
    }
}
