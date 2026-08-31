package com.fightdeck.baseline.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.baseline.core.BetMode
import com.fightdeck.baseline.core.BetSlip
import com.fightdeck.baseline.core.BoutIndex
import com.fightdeck.baseline.core.FightCore
import com.fightdeck.baseline.core.Money
import com.fightdeck.baseline.core.Selection
import com.fightdeck.baseline.core.SlipState
import com.fightdeck.baseline.data.BoutItem
import com.fightdeck.baseline.data.EventItem
import com.fightdeck.baseline.data.FighterItem
import com.fightdeck.baseline.data.JsonFileRepository
import com.fightdeck.baseline.data.MediaItem
import com.fightdeck.baseline.data.NewsItem
import com.fightdeck.baseline.services.DatasetLocator
import com.fightdeck.baseline.services.LocalAssetServer
import java.math.BigDecimal
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
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

/** Shared: building a Json format per call re-derives the serializers each time. */
private val lenientJson = Json { ignoreUnknownKeys = true }

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private var repository: JsonFileRepository? = null
    private var fightCore: FightCore? = null

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()

    private val _events = MutableStateFlow<LoadState<List<EventItem>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventItem>>> = _events.asStateFlow()

    private val _fighters = MutableStateFlow<LoadState<List<FighterItem>>>(LoadState.Loading)
    val fighters: StateFlow<LoadState<List<FighterItem>>> = _fighters.asStateFlow()

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
                    repository = engine.repository
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
        val repository: JsonFileRepository,
        val fightCore: FightCore,
    )

    private fun bootstrapEngine(application: Application): Engine {
        val root = DatasetLocator.datasetRoot(application)
        if (!root.resolve("events.json").exists()) {
            error("Dataset not found. Push the repo dataset to /data/local/tmp/fightdeck/dataset and retry.")
        }
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

    fun toggleSelection(bout: BoutItem, fighterId: String, odds: String) {
        _slip.update { slip ->
            val parsedOdds = Money.parse(odds)
            val existingIndex = slip.selections.indexOfFirst { it.boutId == bout.id }
            val selections = slip.selections.toMutableList()
            if (existingIndex >= 0) {
                val existing = selections[existingIndex]
                if (existing.fighterId == fighterId) {
                    selections.removeAt(existingIndex)
                } else {
                    selections[existingIndex] = Selection(bout.id, fighterId, parsedOdds)
                }
            } else {
                selections += Selection(bout.id, fighterId, parsedOdds)
            }
            slip.copy(selections = selections, mode = modeFor(selections.size))
        }
        _betPlacedMessage.value = null
    }

    private fun modeFor(legCount: Int): BetMode =
        if (legCount >= FightCore.MIN_ACCA_LEGS) BetMode.accumulator else BetMode.single

    fun applySlipJSON(slipJSON: String) {
        val slip = parseSlipJSON(slipJSON) ?: return
        _slip.value = slip.copy(mode = modeFor(slip.selections.size))
    }

    fun placeBetFromSDK(message: String, slipJSON: String, balanceString: String) {
        parseSlipJSON(slipJSON)?.let { parsed ->
            _slip.value = parsed.copy(mode = modeFor(parsed.selections.size))
        }
        _balance.value = Money.parse(balanceString)
        _betPlacedMessage.value = message
    }

    fun deposit(amount: BigDecimal) {
        _balance.update { it.add(amount) }
    }

    fun slipJSON(): String {
        val slip = _slip.value
        val selections = slip.selections.joinToString(",") { sel ->
            """{"boutId":"${sel.boutId}","fighterId":"${sel.fighterId}","odds":"${Money.format(sel.odds)}"}"""
        }
        return """{"mode":"${slip.mode.name}","stake":"${Money.format(slip.stake)}","selections":[$selections]}"""
    }

    fun eventsJSON(): String =
        requireNotNull(repository).let {
            DatasetLocator.datasetRoot(getApplication()).resolve("events.json").readText()
        }

    private fun parseSlipJSON(slipJSON: String): BetSlip? = runCatching {
        val envelope = lenientJson.decodeFromString<SlipEnvelope>(slipJSON)
        BetSlip(
            mode = BetMode.valueOf(envelope.mode),
            selections = envelope.selections.map { Selection(it.boutId, it.fighterId, Money.parse(it.odds)) },
            stake = Money.parse(envelope.stake),
        )
    }.getOrNull()

    private fun buildFightCore(root: java.io.File): FightCore {
        val events = lenientJson
            .decodeFromString<EventsEnvelope>(
                root.resolve("events.json").readText(),
            )
        val bouts = events.events.flatMap { it.bouts }.map {
            BoutIndex(it.id, it.redCorner.fighterId, it.blueCorner.fighterId, it.result.winnerId)
        }
        return FightCore(bouts.associateBy { it.id })
    }
}

@kotlinx.serialization.Serializable
private data class SlipEnvelope(
    val mode: String,
    val stake: String,
    val selections: List<SlipSelectionEnvelope>,
)

@kotlinx.serialization.Serializable
private data class SlipSelectionEnvelope(
    val boutId: String,
    val fighterId: String,
    val odds: String,
)

@kotlinx.serialization.Serializable
private data class EventsEnvelope(val events: List<EventEnvelope>)

@kotlinx.serialization.Serializable
private data class EventEnvelope(val bouts: List<BoutEnvelope>)

@kotlinx.serialization.Serializable
private data class BoutEnvelope(
    val id: String,
    val redCorner: CornerEnvelope,
    val blueCorner: CornerEnvelope,
    val result: ResultEnvelope,
)

@kotlinx.serialization.Serializable
private data class CornerEnvelope(@kotlinx.serialization.SerialName("fighterId") val fighterId: String)

@kotlinx.serialization.Serializable
private data class ResultEnvelope(@kotlinx.serialization.SerialName("winnerId") val winnerId: String)
