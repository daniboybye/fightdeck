package com.fightdeck.baseline.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fightdeck.baseline.services.DatasetLocator
import fight.deck.core.BetSlipStore
import fight.deck.core.FightCore
import fight.deck.events.AssetServer
import fight.deck.events.CatalogModel
import fight.deck.events.EventCatalog
import skip.foundation.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

sealed interface BootstrapState {
    data class Loading(val step: String) : BootstrapState
    data class Failed(val message: String) : BootstrapState
    data object Ready : BootstrapState
}

class MainViewModel(application: Application) : AndroidViewModel(application) {
    /**
     * Events, fighters, news and media with their load states — the same shared model the iOS
     * host holds. Like the slip store its properties are Compose state, so screens read them
     * directly. Set once the dataset is found, before anything leaves the bootstrap screen.
     */
    lateinit var catalog: CatalogModel
        private set

    /**
     * The slip, the balance and the bet confirmation, shared with the bet slip SDK. Its reads
     * are Compose state — skipstone backs every `@Observable` property with a `MutableState` —
     * so a composable that reads `slipStore.slip` recomposes when the SDK changes it. Set once
     * the dataset has produced a core, which is before anything leaves the bootstrap screen.
     */
    lateinit var slipStore: BetSlipStore
        private set

    private val _bootstrapState = MutableStateFlow<BootstrapState>(
        BootstrapState.Loading("Loading fight core…"),
    )
    val bootstrapState: StateFlow<BootstrapState> = _bootstrapState.asStateFlow()


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
                    catalog = CatalogModel(catalog = engine.catalog)
                    slipStore = BetSlipStore(fightCore = engine.fightCore)
                    _bootstrapState.value = BootstrapState.Ready
                    catalog.loadAll()
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
        AssetServer.shared.start(root.absolutePath)
        // The shared catalogue speaks Foundation's URL, so the host's File has to be converted
        // once here rather than at every call.
        val catalog = EventCatalog(datasetRoot = URL(fileURLWithPath = root.absolutePath))
        return Engine(catalog, catalog.loadFightCore())
    }

    fun refreshEvents() {
        viewModelScope.launch { catalog.loadEvents() }
    }

    fun imageUrl(path: String): String? = AssetServer.shared.url(path)
}
