package com.fightdeck.rust.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.rust.core.FightCoreDisplay
import com.fightdeck.rust.core.StateFlowBetSlipStore
import com.fightdeck.rust.core.validationErrorCode
import com.fightdeck.rust.data.BoutItem
import com.fightdeck.rust.data.EventItem
import com.fightdeck.rust.data.FighterItem
import com.fightdeck.rust.data.JsonFileRepository
import com.fightdeck.rust.data.MediaItem
import com.fightdeck.rust.data.NewsItem
import com.fightdeck.rust.services.DatasetLocator
import com.fightdeck.rust.services.LocalAssetServer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
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

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = JsonFileRepository.create(application)
    private val core = buildFightCore()
    private val slipStoreBacking = uniffi.fightcore.BetSlipStore(core, "500.00")
    private val slipStore = StateFlowBetSlipStore(slipStoreBacking)

    private val _events = MutableStateFlow<LoadState<List<EventItem>>>(LoadState.Loading)
    val events: StateFlow<LoadState<List<EventItem>>> = _events.asStateFlow()

    private val _fighters = MutableStateFlow<LoadState<List<FighterItem>>>(LoadState.Loading)
    val fighters: StateFlow<LoadState<List<FighterItem>>> = _fighters.asStateFlow()

    private val _news = MutableStateFlow<LoadState<List<NewsItem>>>(LoadState.Loading)
    val news: StateFlow<LoadState<List<NewsItem>>> = _news.asStateFlow()

    private val _media = MutableStateFlow<LoadState<List<MediaItem>>>(LoadState.Loading)
    val media: StateFlow<LoadState<List<MediaItem>>> = _media.asStateFlow()

    val slipState: StateFlow<SlipStateRecord> = slipStore.slipState
    val slip: StateFlow<BetSlipRecord> = slipStore.slip
    val balance: StateFlow<String> = slipStore.balance

    private val _betPlacedMessage = MutableStateFlow<String?>(null)
    val betPlacedMessage: StateFlow<String?> = _betPlacedMessage.asStateFlow()

    var simulateNetworkFailure = false

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
        slipStore.toggleSelection(bout.id, fighterId, odds)
        _betPlacedMessage.value = null
    }

    fun isSelected(boutId: String, fighterId: String): Boolean =
        slipStore.isSelected(boutId, fighterId)

    fun updateStake(stake: String) {
        slipStore.setStake(stake)
    }

    fun removeSelection(boutId: String, fighterId: String) {
        slipStore.removeSelection(boutId, fighterId)
        _betPlacedMessage.value = null
    }

    fun placeBet() {
        val state = slipStore.placeBet() ?: return
        _betPlacedMessage.value =
            "Bet placed · ${FightCoreDisplay.formatCurrencyAmount(state.potentialReturn)} to return"
    }

    fun deposit(amount: String) {
        slipStore.deposit(amount)
    }

    fun slipSummary(state: SlipStateRecord) = FightCoreDisplay.slipSummary(state)

    fun formatOdds(odds: String) = FightCoreDisplay.formatOdds(odds)
    fun formatCurrency(amount: String) = FightCoreDisplay.formatCurrencyAmount(amount)
    fun errorCode(error: uniffi.fightcore.ValidationErrorRecord) = validationErrorCode(error)

    private fun buildFightCore(): FightCoreHandle {
        val events = Json { ignoreUnknownKeys = true }
            .decodeFromString<EventsEnvelope>(
                DatasetLocator.datasetRoot(getApplication())
                    .resolve("events.json")
                    .readText(),
            )
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

    override fun onCleared() {
        slipStore.close()
        core.close()
        super.onCleared()
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
