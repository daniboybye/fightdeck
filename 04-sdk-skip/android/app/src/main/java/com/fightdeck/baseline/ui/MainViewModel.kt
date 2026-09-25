package com.fightdeck.baseline.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.baseline.services.DatasetLocator
import com.fightdeck.baseline.services.LocalAssetServer
import fight.deck.core.BetMode
import fight.deck.core.BetSlip
import fight.deck.core.Bout
import fight.deck.core.Event
import fight.deck.core.FightCore
import fight.deck.core.Fighter
import fight.deck.core.Money
import fight.deck.core.Selection
import fight.deck.core.SlipState
import fight.deck.events.EventCatalog
import fight.deck.events.MediaItem
import fight.deck.events.NewsItem
import java.math.BigDecimal
import skip.foundation.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import skip.lib.Array as SkipArray

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
    private var catalog: EventCatalog? = null
    private var fightCore: FightCore? = null

    /// The SDK's bet-slip store needs the same bout index the host already built. Handing this
    /// one out beats parsing the dataset a second time to construct an identical core.
    val sharedFightCore: FightCore
        get() = requireNotNull(fightCore)

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    private val _events = MutableStateFlow<LoadState<List<Event>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<Event>>> = _events.asStateFlow()

    private val _fighters = MutableStateFlow<LoadState<List<Fighter>>>(LoadState.Loading)
    val fighters: StateFlow<LoadState<List<Fighter>>> = _fighters.asStateFlow()

    // BetSlip arrives from the SDK as transpiled Swift, so its selections are a
    // skip.lib.Array rather than a Kotlin List.
    private val _slip = MutableStateFlow(
        BetSlip(BetMode.single, SkipArray(emptyList()), BigDecimal("10.00")),
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
        get() = requireNotNull(fightCore).slipState(_slip.value, _balance.value)

    init {
        bootstrap()
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
                    catalog = engine.catalog
                    fightCore = engine.fightCore
                    _bootstrapState.value = BootstrapState.Ready
                    refreshEvents()
                    refreshFighters()
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
        val catalog: EventCatalog,
        val fightCore: FightCore,
    )

    private fun bootstrapEngine(application: Application): Engine {
        val root = DatasetLocator.datasetRoot(application)
        LocalAssetServer.start(root)
        // The shared catalogue speaks Foundation's URL, so the host's File has to be converted
        // once here rather than at every call.
        val catalog = EventCatalog(datasetRoot = URL(fileURLWithPath = root.absolutePath))
        return Engine(catalog, catalog.loadFightCore())
    }

    fun refreshEvents() {
        viewModelScope.launch {
            _events.value = LoadState.Loading
            _events.value = loadCatalogue("events") { it.loadEvents() }
        }
    }

    fun refreshFighters() {
        viewModelScope.launch {
            _fighters.value = LoadState.Loading
            _fighters.value = loadCatalogue("fighters") { it.loadFighters() }
        }
    }

    fun refreshNews() {
        viewModelScope.launch {
            _news.value = LoadState.Loading
            _news.value = loadCatalogue("news") { it.loadNews() }
        }
    }

    fun refreshMedia() {
        viewModelScope.launch {
            _media.value = LoadState.Loading
            _media.value = loadCatalogue("media") { it.loadMedia() }
        }
    }

    /**
     * Two seams in one place: the shared catalogue is synchronous, so leaving the main thread is
     * the host's job, and it hands back Swift's Array, which every Compose list wants as a
     * Kotlin List. The transpiled Array is an Iterable, so toList() stays type-safe.
     */
    private suspend fun <T> loadCatalogue(
        label: String,
        read: (EventCatalog) -> SkipArray<T>,
    ): LoadState<List<T>> {
        val catalog = requireNotNull(catalog)
        return runCatching { withContext(Dispatchers.IO) { read(catalog).toList() } }
            .fold(
                onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                onFailure = { LoadState.Error("Could not load $label") },
            )
    }

    /**
     * Dataset images are served over localhost, so the URL depends on the port the host's asset
     * server happened to bind — nothing the shared catalogue can know.
     */
    fun imageUrl(path: String): String? =
        if (LocalAssetServer.port > 0) "http://127.0.0.1:${LocalAssetServer.port}/$path" else null

    // A transpiled Swift struct has no generated copy(), so an edited slip is rebuilt rather
    // than copied. Mutating one in place would be worse than verbose: BetSlip is a reference
    // type on this side, and the instance is shared with whatever the SDK still holds.
    fun toggleSelection(bout: Bout, fighterId: String, odds: String) {
        _slip.update { slip ->
            val parsedOdds = Money.parse(odds)
            val selections = slip.selections.toList().toMutableList()
            val existingIndex = selections.indexOfFirst { it.boutID == bout.id }
            if (existingIndex >= 0) {
                if (selections[existingIndex].fighterID == fighterId) {
                    selections.removeAt(existingIndex)
                } else {
                    selections[existingIndex] = Selection(bout.id, fighterId, parsedOdds)
                }
            } else {
                selections += Selection(bout.id, fighterId, parsedOdds)
            }
            BetSlip(modeFor(selections.size), SkipArray(selections), slip.stake)
        }
        _betPlacedMessage.value = null
    }

    private fun modeFor(legCount: Int): BetMode =
        if (legCount >= FightCore.minAccaLegs) BetMode.accumulator else BetMode.single

    fun applySdkSlip(slip: BetSlip, balance: BigDecimal, betPlacedMessage: String?) {
        // Rebuilt for the same reason: the SDK keeps its own reference to this slip.
        _slip.value = BetSlip(slip.mode, SkipArray(slip.selections.toList()), slip.stake)
        _balance.value = balance
        _betPlacedMessage.value = betPlacedMessage
    }

    fun deposit(amount: BigDecimal) {
        _balance.update { it.add(amount) }
    }
}
