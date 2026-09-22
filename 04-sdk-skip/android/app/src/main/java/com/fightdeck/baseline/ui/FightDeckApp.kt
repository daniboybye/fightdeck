package com.fightdeck.baseline.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ShortNavigationBar
import androidx.compose.material3.ShortNavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.fightdeck.baseline.design.BalanceMenuAction
import com.fightdeck.baseline.design.Tokens
import fight.deck.core.Money
import java.math.BigDecimal

/**
 * Both event tabs render the same two events. The mode decides which half of the data is
 * relevant: betting needs odds and must not spoil the result, browsing history needs the
 * result and has nothing to bet on.
 */
enum class EventMode(val title: String) {
    Upcoming("Upcoming"),
    Past("Past"),
    ;

    val showsOdds: Boolean get() = this == Upcoming
    val showsResults: Boolean get() = this == Past
}

private const val UPCOMING_TAB = 0

private const val PAST_TAB = 1

private const val SLIP_TAB = 2

/** Scroll inset that clears pinned primary actions when scaffold padding reads zero. */
private fun pinnedScrollBottomInset(scaffoldBottom: Dp): Dp =
    maxOf(
        scaffoldBottom + Tokens.spacingLg,
        Tokens.primaryActionHeight + Tokens.actionBarGap + Tokens.spacingSm + Tokens.spacingLg,
    )

// MaterialExpressiveTheme and the floating toolbar are still internal in material3 1.4.0, so
// the expressive look comes from what is public: ShortNavigationBar, the tonal button set and
// the surface-container roles.

@Composable
private fun BootstrapScreen(
    message: String,
    showProgress: Boolean,
    onRetry: (() -> Unit)? = null,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Tokens.background),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingLg),
            modifier = Modifier.padding(horizontal = Tokens.spacingXl),
        ) {
            if (showProgress) {
                CircularProgressIndicator(color = Tokens.accent)
            }
            Text(
                message,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (onRetry != null) {
                PrimaryActionButton(title = "Retry", onClick = onRetry)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FightDeckApp(viewModel: MainViewModel = viewModel()) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Tokens.accent,
            onPrimary = Tokens.onAccent,
            secondary = Tokens.accent,
            // The selected navigation item takes its label from secondary but its icon and
            // pill from these two, so leaving them out left a stock lavender icon beside a
            // gold label. FilledTonalButton reads the same pair, so the preset amount chips
            // lose the same lavender.
            secondaryContainer = Tokens.surfaceElevated,
            onSecondaryContainer = Tokens.accent,
            background = Tokens.background,
            surface = Tokens.surface,
            surfaceContainer = Tokens.surface,
            surfaceContainerHigh = Tokens.surfaceElevated,
        ),
    ) {
        val bootstrap by viewModel.bootstrapState.collectAsStateWithLifecycle()
        when (val state = bootstrap) {
            is BootstrapState.Loading -> BootstrapScreen(
                message = state.step,
                showProgress = true,
            )
            is BootstrapState.Failed -> BootstrapScreen(
                message = state.message,
                showProgress = false,
                onRetry = viewModel::retryBootstrap,
            )
            BootstrapState.Ready -> FightDeckNavHost(viewModel)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
/**
 * Deposit is a destination pushed over the tabs, not a bottom sheet. iOS presents it as a sheet
 * because that is what a self-contained task looks like there; on Android the same flow is a
 * screen, which is also what gives it the system back gesture and the platform's push
 * transition for free.
 */
@Composable
private fun FightDeckNavHost(viewModel: MainViewModel) {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = "tabs") {
        composable("tabs") {
            FightDeckMain(viewModel, onDeposit = { nav.navigate("deposit") })
        }
        composable("deposit") {
            // The transpiled form declares its own navigation bar and Close button, so unlike
            // the other four hosts there is no Compose chrome to write here. It also lays itself
            // out over the keyboard, so the surface is shrunk to the space the keys leave —
            // the same glue the slip screen needs.
            Box(Modifier.imePadding()) {
                com.fightdeck.baseline.sdk.SkipSDKBridge.DepositScreen(
                    viewModel = viewModel,
                    saveKey = "deposit-screen",
                    onDone = { nav.popBackStack() },
                )
            }
        }
    }
}

@Composable
private fun FightDeckMain(viewModel: MainViewModel, onDeposit: () -> Unit) {
        val slip by viewModel.slip.collectAsStateWithLifecycle()
        val balance by viewModel.balance.collectAsStateWithLifecycle()

        // Saveable, not plain remember: pushing the deposit destination takes the tab host out
        // of composition, and a plain remember would hand the user back the first tab instead
        // of the one they left. The per-tab nav controllers already save themselves.
        var selectedTab by rememberSaveable { mutableIntStateOf(UPCOMING_TAB) }
        val upcomingNav = rememberNavController()
        val pastNav = rememberNavController()
        val slipNav = rememberNavController()
        // The bar is a shortcut into the slip on every tab while selections exist — matching
        // iOS tabViewBottomAccessory. isEmpty and count come from the SDK's Swift Array, so the
        // Kotlin isNotEmpty()/size idioms are not available here.
        val showsSlipToolbar = !slip.selections.isEmpty

        Scaffold(
            modifier = Modifier.fillMaxSize(),
            containerColor = Tokens.background,
            bottomBar = {
                // Nothing but the picture belongs in the floating window.
                if (!isInFloatingWindow()) {
                    Column {
                        // In the bottom bar rather than the floating-action slot: the slot
                        // floats over the content, and this bar has to be part of the scroll
                        // insets so it never covers the last row.
                        if (showsSlipToolbar) {
                            BetSlipToolbar(
                                legCount = slip.selections.count,
                                potentialReturn = Money.formatCurrency(viewModel.slipState.potentialReturn),
                                onClick = { selectedTab = SLIP_TAB },
                                modifier = Modifier
                                    .align(Alignment.CenterHorizontally)
                                    // Same gutter as the lists behind it, so the pill reads as
                                    // part of the page instead of a bar wedged edge to edge.
                                    .padding(horizontal = Tokens.spacingLg)
                                    .padding(bottom = Tokens.spacingSm),
                            )
                        }
                        ShortNavigationBar(containerColor = Tokens.surface) {
                            ShortNavigationBarItem(
                                selected = selectedTab == UPCOMING_TAB,
                                onClick = { selectedTab = UPCOMING_TAB },
                                icon = { Icon(Icons.Default.DateRange, contentDescription = null) },
                                label = { Text("Upcoming") },
                            )
                            ShortNavigationBarItem(
                                selected = selectedTab == PAST_TAB,
                                onClick = { selectedTab = PAST_TAB },
                                icon = { Icon(Icons.Default.Star, contentDescription = null) },
                                label = { Text("Past") },
                            )
                            ShortNavigationBarItem(
                                selected = selectedTab == SLIP_TAB,
                                onClick = { selectedTab = SLIP_TAB },
                                icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) },
                                label = { Text("Slip") },
                            )
                        }
                    }
                }
            },
        ) { padding ->
            // Consuming the padding this scaffold already spent lets anything inside measure a
            // keyboard lift from the space the tab content actually gets, instead of stacking it
            // on top of the tab bar's height.
            Box(
                Modifier
                    .padding(padding)
                    .consumeWindowInsets(padding),
            ) {
                when (selectedTab) {
                    UPCOMING_TAB -> EventsNavHost(
                        nav = upcomingNav,
                        mode = EventMode.Upcoming,
                        viewModel = viewModel,
                        balance = balance,
                        onDeposit = onDeposit,
                        modifier = Modifier.fillMaxSize(),
                    )

                    PAST_TAB -> EventsNavHost(
                        nav = pastNav,
                        mode = EventMode.Past,
                        viewModel = viewModel,
                        balance = balance,
                        onDeposit = onDeposit,
                        modifier = Modifier.fillMaxSize(),
                    )

                    // SwiftUI lifts the slip's bottom bar over the keyboard for free on iOS, but
                    // the transpiled screen arrives on Android with no keyboard awareness at all,
                    // so the host shrinks the surface to the space the keyboard leaves.
                    else -> SlipNavHost(
                        slipNav = slipNav,
                        viewModel = viewModel,
                        onDeposit = onDeposit,
                        onBrowseEvents = { selectedTab = UPCOMING_TAB },
                        modifier = Modifier
                            .fillMaxSize()
                            .imePadding(),
                    )
                }
            }
        }

    }

@Composable
private fun BetSlipToolbar(
    legCount: Int,
    potentialReturn: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
        shape = RoundedCornerShape(percent = 50),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = Tokens.minTapTarget)
                .padding(horizontal = Tokens.spacingXl, vertical = Tokens.spacingMd),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val suffix = if (legCount == 1) "" else "s"
            Text("$legCount selection$suffix", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.width(Tokens.spacingMd))
            Text(
                "Return $potentialReturn",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = Tokens.accent,
            )
        }
    }
}

@Composable
private fun EventsNavHost(
    nav: NavHostController,
    mode: EventMode,
    viewModel: MainViewModel,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val events by viewModel.events.collectAsStateWithLifecycle()
    val fighters by viewModel.fighters.collectAsStateWithLifecycle()
    val news by viewModel.news.collectAsStateWithLifecycle()
    val media by viewModel.media.collectAsStateWithLifecycle()
    // Collected here, not read through viewModel.isSelected(): a plain getter is invisible to
    // Compose, so an odds tap only showed up once something else forced a recomposition.
    val slip by viewModel.slip.collectAsStateWithLifecycle()
    val loadedEvents = (events as? LoadState.Loaded)?.value.orEmpty()
    val loadedFighters = (fighters as? LoadState.Loaded)?.value.orEmpty()

    NavHost(navController = nav, startDestination = "events", modifier = modifier) {
        composable("events") {
            EventListScreen(
                state = events,
                news = news,
                media = media,
                mode = mode,
                viewModel = viewModel,
                balance = balance,
                onDeposit = onDeposit,
                onRetry = viewModel::refreshEvents,
                onEventClick = { nav.navigate("event/${it.id}") },
                onArticleClick = { nav.navigate("article/${it.id}") },
                onVideoClick = { nav.navigate("video/${it.id}") },
            )
        }
        composable(
            "event/{eventId}",
            arguments = listOf(navArgument("eventId") { type = NavType.StringType }),
        ) { entry ->
            val event = loadedEvents.firstOrNull { it.id == entry.arguments?.getString("eventId") }
            if (event != null) {
                EventDetailScreen(
                    event = event,
                    mode = mode,
                    slip = slip,
                    viewModel = viewModel,
                    fighters = loadedFighters,
                    media = media,
                    balance = balance,
                    onDeposit = onDeposit,
                    onBoutClick = { nav.navigate("bout/${event.id}/${it.id}") },
                    onVideoClick = { nav.navigate("video/${it.id}") },
                    onBack = { nav.popBackStack() },
                )
            }
        }
        composable(
            "bout/{eventId}/{boutId}",
            arguments = listOf(
                navArgument("eventId") { type = NavType.StringType },
                navArgument("boutId") { type = NavType.StringType },
            ),
        ) { entry ->
            val event = loadedEvents.firstOrNull { it.id == entry.arguments?.getString("eventId") }
            val bout = event?.bouts?.firstOrNull { it.id == entry.arguments?.getString("boutId") }
            if (bout != null) {
                BoutDetailScreen(
                    bout = bout,
                    mode = mode,
                    slip = slip,
                    viewModel = viewModel,
                    fighters = loadedFighters,
                    balance = balance,
                    onDeposit = onDeposit,
                    onFighterClick = { nav.navigate("fighter/$it") },
                    onBack = { nav.popBackStack() },
                )
            }
        }
        composable(
            "fighter/{fighterId}",
            arguments = listOf(navArgument("fighterId") { type = NavType.StringType }),
        ) { entry ->
            val fighter = loadedFighters
                .firstOrNull { it.id == entry.arguments?.getString("fighterId") }
            if (fighter != null) {
                DetailScaffold(
                    title = fighter.name,
                    onBack = { nav.popBackStack() },
                    balance = balance,
                    onDeposit = onDeposit,
                ) { padding ->
                    com.fightdeck.baseline.sdk.SkipSDKBridge.FighterScreen(
                        fighter = fighter,
                        viewModel = viewModel,
                        saveKey = "fighter-${fighter.id}",
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(top = padding.calculateTopPadding()),
                    )
                }
            }
        }
        composable(
            "article/{articleId}",
            arguments = listOf(navArgument("articleId") { type = NavType.StringType }),
        ) { entry ->
            val article = (news as? LoadState.Loaded)?.value
                ?.firstOrNull { it.id == entry.arguments?.getString("articleId") }
            if (article != null) {
                NewsArticleScreen(
                    item = article,
                    media = media,
                    viewModel = viewModel,
                    balance = balance,
                    onDeposit = onDeposit,
                    onVideoClick = { nav.navigate("video/${it.id}") },
                    onBack = { nav.popBackStack() },
                )
            }
        }
        composable(
            "video/{videoId}",
            arguments = listOf(navArgument("videoId") { type = NavType.StringType }),
        ) { entry ->
            val clip = (media as? LoadState.Loaded)?.value
                ?.firstOrNull { it.id == entry.arguments?.getString("videoId") }
            if (clip != null) {
                VideoScreen(clip, balance = balance, onDeposit = onDeposit, onBack = { nav.popBackStack() })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SlipNavHost(
    slipNav: NavHostController,
    viewModel: MainViewModel,
    onDeposit: () -> Unit,
    onBrowseEvents: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val balance by viewModel.balance.collectAsStateWithLifecycle()

    NavHost(navController = slipNav, startDestination = "slip", modifier = modifier) {
        composable("slip") {
            // The title and the balance action are the host's, not the SDK's — the same split
            // the events and fighter screens use, and the same bar `00-native` gives this
            // screen. The SDK view owns the list below it and nothing above it.
            Scaffold(
                containerColor = Color.Transparent,
                topBar = {
                    TopAppBar(
                        title = { Text("Bet Slip", style = MaterialTheme.typography.headlineMedium) },
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                        actions = {
                            BalanceMenuAction(
                                balanceLabel = Money.formatCurrency(balance),
                                onDeposit = onDeposit,
                            )
                        },
                    )
                },
            ) { padding ->
                com.fightdeck.baseline.sdk.SkipSDKBridge.BetslipScreen(
                    viewModel = viewModel,
                    saveKey = "betslip-root",
                    onDeposit = onDeposit,
                    onBrowseEvents = onBrowseEvents,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                )
            }
        }
    }
}
