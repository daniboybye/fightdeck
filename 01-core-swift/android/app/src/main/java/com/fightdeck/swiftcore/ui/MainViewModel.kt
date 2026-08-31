package com.fightdeck.swiftcore.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.swiftcore.bridge.SharedPreferencesStore
import com.fightdeck.swiftcore.bridge.SwiftCoreBridge
import com.fightdeck.swiftcore.core.BetSlip
import com.fightdeck.swiftcore.core.BetSlipStore
import com.fightdeck.swiftcore.core.BetMode
import com.fightdeck.swiftcore.core.FightCore
import com.fightdeck.swiftcore.core.Money
import com.fightdeck.swiftcore.core.SlipState
import com.fightdeck.swiftcore.data.Bout
import com.fightdeck.swiftcore.data.Event
import com.fightdeck.swiftcore.data.Fighter
import com.fightdeck.swiftcore.data.fromEvents
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
import kotlinx.serialization.json.Json

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
    private var fightCore: FightCore? = null

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    init {
        check(SwiftCoreBridge.isStub) {
            "Expected SwiftCoreBridge stub until fightcore.aar is wired"
        }
        preferences.write("swift_core_mode", if (SwiftCoreBridge.isStub) "kotlin_stub" else "swift")
        bootstrap()
    }

    private val _events = MutableStateFlow<LoadState<List<Event>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<Event>>> = _events.asStateFlow()

    private val _fighters = MutableStateFlow<LoadState<List<Fighter>>>(LoadState.Loading)
    val fighters: StateFlow<LoadState<List<Fighter>>> = _fighters.asStateFlow()

    private var slipStore: BetSlipStore? = null

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
                    fightCore = engine.fightCore
                    slipStore = BetSlipStore(engine.fightCore)
                    publishSlipState()
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
        val repository: JsonFileRepository,
        val fightCore: FightCore,
    )

    private fun bootstrapEngine(application: Application): Engine {
        val root = DatasetLocator.datasetRoot(application)
        LocalAssetServer.start(root)
        return Engine(JsonFileRepository(root), buildFightCore(root))
    }

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

    fun toggleSelection(bout: Bout, fighterId: String, odds: String) {
        requireNotNull(slipStore).toggleSelection(bout.id, fighterId, Money.parse(odds))
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

    private fun buildFightCore(root: java.io.File): FightCore {
        val events = Json { ignoreUnknownKeys = true }
            .decodeFromString<EventsEnvelope>(
                root.resolve("events.json").readText(),
            )
        return FightCore.fromEvents(events.events)
    }
}

@kotlinx.serialization.Serializable
private data class EventsEnvelope(val events: List<Event>)
