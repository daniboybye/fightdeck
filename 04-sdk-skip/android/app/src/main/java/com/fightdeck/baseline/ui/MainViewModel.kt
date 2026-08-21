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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json

sealed interface LoadState<out T> {
    data object Loading : LoadState<Nothing>
    data class Loaded<T>(val value: T) : LoadState<T>
    data object Empty : LoadState<Nothing>
    data class Error(val message: String) : LoadState<Nothing>
}

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = JsonFileRepository.create(application)
    private val fightCore = buildFightCore()

    private val _events = MutableStateFlow<LoadState<List<EventItem>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventItem>>> = _events.asStateFlow()

    private val _fighters = MutableStateFlow<LoadState<List<FighterItem>>>(LoadState.Loading)
    val fighters: StateFlow<LoadState<List<FighterItem>>> = _fighters.asStateFlow()

    private val _slip = MutableStateFlow(
        BetSlip(BetMode.accumulator, emptyList(), BigDecimal("10.00")),
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

    var simulateNetworkFailure = false

    val slipState: SlipState
        get() = fightCore.slipState(_slip.value, _balance.value)

    init {
        LocalAssetServer.start(application)
        refreshEvents()
        refreshFighters()
        refreshNews()
        refreshMedia()
    }

    fun refreshEvents() {
        viewModelScope.launch {
            _events.value = LoadState.Loading
            repository.shouldFail = simulateNetworkFailure
            _events.value = runCatching { repository.loadEvents() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load events") },
                )
        }
    }

    fun refreshFighters() {
        viewModelScope.launch {
            _fighters.value = LoadState.Loading
            _fighters.value = runCatching { repository.loadFighters() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load fighters") },
                )
        }
    }

    fun refreshNews() {
        viewModelScope.launch {
            _news.value = LoadState.Loading
            _news.value = runCatching { repository.loadNews() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load news") },
                )
        }
    }

    fun refreshMedia() {
        viewModelScope.launch {
            _media.value = LoadState.Loading
            _media.value = runCatching { repository.loadMedia() }
                .fold(
                    onSuccess = { if (it.isEmpty()) LoadState.Empty else LoadState.Loaded(it) },
                    onFailure = { LoadState.Error("Could not load media") },
                )
        }
    }

    fun imageUrl(path: String): String = repository.imageUrl(path)

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
            slip.copy(selections = selections)
        }
        _betPlacedMessage.value = null
    }

    fun isSelected(boutId: String, fighterId: String): Boolean =
        _slip.value.selections.any { it.boutId == boutId && it.fighterId == fighterId }

    fun applySdkSlip(slip: BetSlip, balance: BigDecimal, betPlacedMessage: String?) {
        _slip.value = slip
        _balance.value = balance
        _betPlacedMessage.value = betPlacedMessage
    }

    fun deposit(amount: BigDecimal) {
        _balance.update { it.add(amount) }
    }

    private fun buildFightCore(): FightCore {
        val events = Json { ignoreUnknownKeys = true }
            .decodeFromString<EventsEnvelope>(
                DatasetLocator.datasetRoot(getApplication())
                    .resolve("events.json")
                    .readText(),
            )
        val bouts = events.events.flatMap { it.bouts }.map {
            BoutIndex(it.id, it.redCorner.fighterId, it.blueCorner.fighterId, it.result.winnerId)
        }
        return FightCore(bouts.associateBy { it.id })
    }
}

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
