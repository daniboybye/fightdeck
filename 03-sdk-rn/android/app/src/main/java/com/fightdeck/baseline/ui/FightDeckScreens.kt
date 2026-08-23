package com.fightdeck.baseline.ui

import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ShortNavigationBar
import androidx.compose.material3.ShortNavigationBarItem
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import coil3.compose.AsyncImage
import com.fightdeck.baseline.core.BetMode
import com.fightdeck.baseline.core.BetSlip
import com.fightdeck.baseline.core.Money
import com.fightdeck.baseline.core.SlipState
import com.fightdeck.baseline.data.BoutItem
import com.fightdeck.baseline.data.CornerItem
import com.fightdeck.baseline.data.EventItem
import com.fightdeck.baseline.data.FighterItem
import com.fightdeck.baseline.data.MediaItem
import com.fightdeck.baseline.data.NewsItem
import com.fightdeck.baseline.design.Tokens
import java.math.BigDecimal
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

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

private const val DEPOSIT_ROUTE = "deposit"
private const val UPCOMING_TAB = 0
private const val PAST_TAB = 1
private const val SLIP_TAB = 2

// MaterialExpressiveTheme and the floating toolbar are still internal in material3 1.4.0, so
// the expressive look comes from what is public: ShortNavigationBar, the tonal button set and
// the surface-container roles.
@Composable
fun FightDeckApp(viewModel: MainViewModel = viewModel()) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Tokens.accent,
            onPrimary = Tokens.onAccent,
            secondary = Tokens.accent,
            background = Tokens.background,
            surface = Tokens.surface,
            surfaceContainer = Tokens.surface,
            surfaceContainerHigh = Tokens.surfaceElevated,
        ),
    ) {
        val slip by viewModel.slip.collectAsStateWithLifecycle()

        var selectedTab by remember { mutableIntStateOf(UPCOMING_TAB) }
        val upcomingNav = rememberNavController()
        val pastNav = rememberNavController()
        val slipNav = rememberNavController()
        val slipEntry by slipNav.currentBackStackEntryAsState()

        // The deposit flow is a single self-contained task; the tab bar would invite the user
        // to abandon it half-way.
        val onDeposit = slipEntry?.destination?.route == DEPOSIT_ROUTE

        // The bar is a shortcut into the slip while you are picking odds, so it belongs to the
        // tab you pick odds on.
        val showsSlipToolbar = selectedTab == UPCOMING_TAB && slip.selections.isNotEmpty()

        Scaffold(
            modifier = Modifier.fillMaxSize(),
            containerColor = Tokens.background,
            bottomBar = {
                if (!onDeposit) {
                    Column {
                        // In the bottom bar rather than the floating-action slot: the slot
                        // floats over the content, and this bar has to be part of the scroll
                        // insets so it never covers the last row.
                        if (showsSlipToolbar) {
                            BetSlipToolbar(
                                legCount = slip.selections.size,
                                potentialReturn = Money.formatCurrency(viewModel.slipState.potentialReturn),
                                onClick = { selectedTab = SLIP_TAB },
                                modifier = Modifier
                                    .align(Alignment.CenterHorizontally)
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
            Box(Modifier.padding(padding)) {
                when (selectedTab) {
                    UPCOMING_TAB -> EventsNavHost(
                        nav = upcomingNav,
                        mode = EventMode.Upcoming,
                        viewModel = viewModel,
                        modifier = Modifier.fillMaxSize(),
                    )

                    PAST_TAB -> EventsNavHost(
                        nav = pastNav,
                        mode = EventMode.Past,
                        viewModel = viewModel,
                        modifier = Modifier.fillMaxSize(),
                    )

                    else -> SlipNavHost(
                        slipNav = slipNav,
                        viewModel = viewModel,
                        onBrowseEvents = { selectedTab = UPCOMING_TAB },
                        modifier = Modifier.fillMaxSize(),
                    )
                }
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
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
        shape = RoundedCornerShape(percent = 50),
    ) {
        Row(
            Modifier.padding(horizontal = Tokens.spacingXl, vertical = Tokens.spacingLg),
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
                mode = mode,
                viewModel = viewModel,
                onRetry = viewModel::refreshEvents,
                onEventClick = { nav.navigate("event/${it.id}") },
                onArticleClick = { nav.navigate("article/${it.id}") },
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
                FighterProfileScreen(fighter, viewModel, onBack = { nav.popBackStack() })
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
                VideoScreen(clip, onBack = { nav.popBackStack() })
            }
        }
    }
}

@Composable
private fun SlipNavHost(
    slipNav: NavHostController,
    viewModel: MainViewModel,
    onBrowseEvents: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val balance by viewModel.balance.collectAsStateWithLifecycle()

    NavHost(navController = slipNav, startDestination = "slip", modifier = modifier) {
        composable("slip") {
            RNBetslipScreen(
                balance = balance,
                slipJSON = viewModel.slipJSON(),
                eventsJSON = viewModel.eventsJSON(),
                onBrowseEvents = onBrowseEvents,
                onDeposit = { slipNav.navigate(DEPOSIT_ROUTE) },
                onUpdated = viewModel::applySlipJSON,
                onPlaced = viewModel::placeBetFromSDK,
            )
        }
        composable(DEPOSIT_ROUTE) {
            RNDepositScreen(
                balance = balance,
                onCompleted = { amount ->
                    viewModel.deposit(amount)
                    slipNav.popBackStack()
                },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EventListScreen(
    state: LoadState<List<EventItem>>,
    news: LoadState<List<NewsItem>>,
    mode: EventMode,
    viewModel: MainViewModel,
    onRetry: () -> Unit,
    onEventClick: (EventItem) -> Unit,
    onArticleClick: (NewsItem) -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(rememberTopAppBarState())

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(mode.title, style = MaterialTheme.typography.headlineMedium) },
                scrollBehavior = scrollBehavior,
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        when (state) {
            LoadState.Loading -> SkeletonColumn(Modifier.padding(padding))
            is LoadState.Empty -> EmptyState("No events", Modifier.padding(padding))
            is LoadState.Error -> ErrorState(onRetry, Modifier.padding(padding))
            is LoadState.Loaded -> LazyColumn(
                contentPadding = PaddingValues(
                    start = Tokens.spacingLg,
                    end = Tokens.spacingLg,
                    top = padding.calculateTopPadding(),
                    bottom = Tokens.spacingXl,
                ),
                verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
            ) {
                items(state.value, key = { it.id }) { event ->
                    EventCard(
                        event = event,
                        mode = mode,
                        posterUrl = viewModel.imageUrl("assets/events/${event.id}.jpg"),
                        onClick = { onEventClick(event) },
                    )
                }
                if (mode.showsResults) {
                    val articles = (news as? LoadState.Loaded)?.value.orEmpty()
                    if (articles.isNotEmpty()) {
                        item {
                            SectionHeader("News")
                        }
                        items(articles, key = { it.id }) { article ->
                            NewsCard(
                                item = article,
                                eventName = state.value.firstOrNull { it.id == article.eventId }?.name.orEmpty(),
                                imageUrl = viewModel.imageUrl(article.heroImage),
                                onClick = { onArticleClick(article) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(top = Tokens.spacingLg, bottom = Tokens.spacingXs),
    )
}

@Composable
private fun EventCard(event: EventItem, mode: EventMode, posterUrl: String, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        AsyncImage(
            model = posterUrl,
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp),
            contentScale = ContentScale.Crop,
        )
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs),
        ) {
            Text(event.name, style = MaterialTheme.typography.titleLarge)
            Text(
                "${event.venue} · ${event.city}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${event.date.displayDate} · ${event.bouts.size} fights",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                StatusBadge(mode)
            }
        }
    }
}

@Composable
private fun StatusBadge(mode: EventMode) {
    val tint = if (mode.showsResults) Tokens.positive else Tokens.accent
    Surface(color = tint.copy(alpha = 0.15f), shape = RoundedCornerShape(Tokens.radiusLg)) {
        Text(
            if (mode.showsResults) "FINISHED" else "OPEN",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = tint,
            modifier = Modifier.padding(horizontal = Tokens.spacingSm, vertical = Tokens.spacingXs),
        )
    }
}

@Composable
private fun NewsCard(item: NewsItem, eventName: String, imageUrl: String, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        AsyncImage(
            model = imageUrl,
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp),
            contentScale = ContentScale.Crop,
        )
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs),
        ) {
            // Every article carries its event, and the feed mixes both cards, so the row has to
            // say which event it belongs to.
            if (eventName.isNotEmpty()) {
                Text(
                    eventName.uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = Tokens.accent,
                )
            }
            Text(item.headline, style = MaterialTheme.typography.titleMedium, maxLines = 3)
            Text(
                item.body,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
            )
            Text(
                "${item.readMinutes} min read",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EventDetailScreen(
    event: EventItem,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<FighterItem>,
    media: LoadState<List<MediaItem>>,
    onBoutClick: (BoutItem) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = event.name, onBack = onBack) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            items(event.bouts.sortedBy { it.order }, key = { it.id }) { bout ->
                BoutRow(bout, mode, slip, viewModel, fighters, onClick = { onBoutClick(bout) })
            }
            if (mode.showsResults) {
                val clips = (media as? LoadState.Loaded)?.value.orEmpty().filter { it.eventId == event.id }
                if (clips.isNotEmpty()) {
                    item { SectionHeader("Video") }
                    items(clips, key = { it.id }) { clip ->
                        ListItem(
                            headlineContent = { Text(clip.title) },
                            supportingContent = { Text(clip.durationLabel) },
                            leadingContent = {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Tokens.accent)
                            },
                            colors = ListItemDefaults.colors(
                                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                            ),
                            modifier = Modifier
                                .clip(RoundedCornerShape(Tokens.radiusLg))
                                .clickable { onVideoClick(clip) },
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailScaffold(
    title: String,
    onBack: () -> Unit,
    content: @Composable (PaddingValues) -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(rememberTopAppBarState())
    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(title, maxLines = 1) },
                navigationIcon = { BackButton(onBack) },
                scrollBehavior = scrollBehavior,
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        content = content,
    )
}

@Composable
private fun BoutRow(
    bout: BoutItem,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<FighterItem>,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        ) {
            val title = bout.weightClass.replace('_', ' ').uppercase() +
                if (bout.titleFight) " · TITLE" else ""
            Text(
                "$title · ${bout.scheduledRounds} RNDS",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CornerLine(bout.redCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerRed)
            CornerLine(bout.blueCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerBlue)
            if (mode.showsResults) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = null,
                        tint = Tokens.positive,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(Tokens.spacingXs))
                    Text(
                        "${bout.result.winnerName} · ${bout.result.method.displayMethod} · " +
                            "R${bout.result.endRound} ${bout.result.endTime}",
                        style = MaterialTheme.typography.labelMedium,
                        color = Tokens.positive,
                    )
                }
            }
        }
    }
}

@Composable
private fun CornerLine(
    corner: CornerItem,
    bout: BoutItem,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<FighterItem>,
    ring: Color,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
            FighterAvatar(viewModel.imageUrl("assets/fighters/${corner.fighterId}.jpg"), ring, 40.dp)
            Spacer(Modifier.width(Tokens.spacingMd))
            Column {
                Text(corner.name, style = MaterialTheme.typography.bodyLarge)
                Text(
                    fighters.firstOrNull { it.id == corner.fighterId }?.record?.display ?: "—",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (mode.showsOdds) {
            OddsChip(
                label = corner.closingOdds.decimal,
                selected = slip.selections.any {
                    it.boutId == bout.id && it.fighterId == corner.fighterId
                },
                onClick = {
                    viewModel.toggleSelection(bout, corner.fighterId, corner.closingOdds.decimal)
                },
            )
        }
    }
}

@Composable
private fun FighterAvatar(url: String, ring: Color, size: Dp) {
    AsyncImage(
        model = url,
        contentDescription = null,
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape)
            .border(2.dp, ring, CircleShape),
        contentScale = ContentScale.Crop,
    )
}

@Composable
private fun OddsChip(label: String, selected: Boolean, onClick: () -> Unit) {
    if (selected) {
        Button(onClick = onClick, shape = RoundedCornerShape(Tokens.radiusMd)) {
            Text(label, fontWeight = FontWeight.SemiBold)
        }
    } else {
        FilledTonalButton(onClick = onClick, shape = RoundedCornerShape(Tokens.radiusMd)) {
            Text(label, fontWeight = FontWeight.SemiBold, color = Tokens.accent)
        }
    }
}

@Composable
private fun BoutDetailScreen(
    bout: BoutItem,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<FighterItem>,
    onFighterClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = bout.weightClass.displayMethod, onBack = onBack) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingLg),
        ) {
            item {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = Tokens.spacingLg),
                    verticalAlignment = Alignment.Top,
                ) {
                    FighterHero(bout.redCorner, Tokens.cornerRed, viewModel, fighters, onFighterClick, Modifier.weight(1f))
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(top = Tokens.spacingXl),
                    ) {
                        Text(
                            "VS",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        if (bout.titleFight) {
                            Icon(Icons.Default.Star, contentDescription = null, tint = Tokens.accent)
                        }
                    }
                    FighterHero(bout.blueCorner, Tokens.cornerBlue, viewModel, fighters, onFighterClick, Modifier.weight(1f))
                }
            }
            item { SectionHeader("Tale of the tape") }
            item { TaleOfTheTape(bout, fighters) }
            if (mode.showsOdds) {
                item { SectionHeader("Outright winner") }
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(
                            Modifier.padding(Tokens.spacingLg),
                            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
                        ) {
                            CornerLine(bout.redCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerRed)
                            CornerLine(bout.blueCorner, bout, mode, slip, viewModel, fighters, Tokens.cornerBlue)
                        }
                    }
                }
            }
            if (mode.showsResults) {
                item { SectionHeader("Result") }
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(Modifier.padding(Tokens.spacingLg)) {
                            DetailRow("Winner", bout.result.winnerName, Tokens.positive)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Method", bout.result.method.displayMethod)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Detail", bout.result.detail)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Ended", "Round ${bout.result.endRound} · ${bout.result.endTime}")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String, valueColor: Color = Color.Unspecified) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            color = if (valueColor == Color.Unspecified) MaterialTheme.colorScheme.onSurface else valueColor,
        )
    }
}

@Composable
private fun FighterHero(
    corner: CornerItem,
    ring: Color,
    viewModel: MainViewModel,
    fighters: List<FighterItem>,
    onClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        modifier = modifier.clickable { onClick(corner.fighterId) },
    ) {
        FighterAvatar(viewModel.imageUrl("assets/fighters/${corner.fighterId}.jpg"), ring, 88.dp)
        Text(
            corner.name,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            fighters.firstOrNull { it.id == corner.fighterId }?.record?.display ?: "—",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun TaleOfTheTape(bout: BoutItem, fighters: List<FighterItem>) {
    fun of(id: String): FighterItem? = fighters.firstOrNull { it.id == id }
    val red = of(bout.redCorner.fighterId)
    val blue = of(bout.blueCorner.fighterId)

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            TapeRow(red?.record?.display, "RECORD", blue?.record?.display)
            TapeRow(red?.heightCm?.let { "$it cm" }, "HEIGHT", blue?.heightCm?.let { "$it cm" })
            TapeRow(red?.reachIn?.let { "$it in" }, "REACH", blue?.reachIn?.let { "$it in" })
            TapeRow(red?.stance?.replaceFirstChar { it.uppercase() }, "STANCE", blue?.stance?.replaceFirstChar { it.uppercase() })
            TapeRow(red?.country, "COUNTRY", blue?.country)
        }
    }
}

/**
 * Weighted columns rather than [Arrangement.SpaceBetween]: space-between distributes the slack
 * between three texts of different widths, so no two rows lined up with each other.
 */
@Composable
private fun TapeRow(left: String?, label: String, right: String?) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            left ?: "—",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Start,
            modifier = Modifier.weight(1f),
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(80.dp),
        )
        Text(
            right ?: "—",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun FighterProfileScreen(fighter: FighterItem, viewModel: MainViewModel, onBack: () -> Unit) {
    DetailScaffold(title = fighter.name, onBack = onBack) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
        ) {
            item {
                Box {
                    AsyncImage(
                        model = viewModel.imageUrl(fighter.portrait),
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(320.dp),
                        contentScale = ContentScale.Crop,
                    )
                    Column(
                        Modifier
                            .align(Alignment.BottomStart)
                            .fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.75f)),
                                ),
                            )
                            .padding(Tokens.spacingLg),
                        verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs),
                    ) {
                        Text(fighter.name, style = MaterialTheme.typography.headlineLarge)
                        fighter.nickname?.let {
                            Text(
                                "\u201C$it\u201D",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            fighter.record.display,
                            style = MaterialTheme.typography.titleSmall,
                            color = Tokens.accent,
                        )
                    }
                }
            }
            item {
                Column(Modifier.padding(Tokens.spacingLg)) {
                    SectionHeader("Profile")
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(Modifier.padding(Tokens.spacingLg)) {
                            DetailRow("Record", fighter.record.display)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Wins", "${fighter.record.wins}")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Losses", "${fighter.record.losses}")
                        }
                    }
                    SectionHeader("Physicals")
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusLg),
                    ) {
                        Column(Modifier.padding(Tokens.spacingLg)) {
                            DetailRow("Height", fighter.heightCm?.let { "$it cm" } ?: "—")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Reach", fighter.reachIn?.let { "$it in" } ?: "—")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Stance", fighter.stance?.replaceFirstChar { it.uppercase() } ?: "—")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Country", fighter.country ?: "—")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NewsArticleScreen(
    item: NewsItem,
    media: LoadState<List<MediaItem>>,
    viewModel: MainViewModel,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = "Article", onBack = onBack) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
        ) {
            item {
                AsyncImage(
                    model = viewModel.imageUrl(item.heroImage),
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp),
                    contentScale = ContentScale.Crop,
                )
            }
            item {
                Column(
                    Modifier.padding(Tokens.spacingLg),
                    verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
                ) {
                    Text(item.headline, style = MaterialTheme.typography.headlineSmall)
                    Text(
                        "${item.readMinutes} min read · ${item.source}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(item.body, style = MaterialTheme.typography.bodyLarge)
                }
            }
            val clips = (media as? LoadState.Loaded)?.value.orEmpty().filter { it.eventId == item.eventId }
            if (clips.isNotEmpty()) {
                item {
                    SectionHeader("Watch", Modifier.padding(horizontal = Tokens.spacingLg))
                }
                items(clips, key = { it.id }) { clip ->
                    ListItem(
                        headlineContent = { Text(clip.title) },
                        leadingContent = {
                            Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Tokens.accent)
                        },
                        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                        modifier = Modifier.clickable { onVideoClick(clip) },
                    )
                }
            }
        }
    }
}

@Composable
private fun VideoScreen(item: MediaItem, onBack: () -> Unit) {
    DetailScaffold(title = "Video", onBack = onBack) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            item {
                AndroidView(
                    factory = { context ->
                        VideoView(context).apply {
                            setVideoPath(item.url)
                            setMediaController(MediaController(context).also { it.setAnchorView(this) })
                            setOnPreparedListener { start() }
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f)
                        .clip(RoundedCornerShape(Tokens.radiusMd)),
                )
            }
            item { Text(item.title, style = MaterialTheme.typography.titleLarge) }
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    shape = RoundedCornerShape(Tokens.radiusLg),
                ) {
                    Column(Modifier.padding(Tokens.spacingLg)) {
                        DetailRow("Duration", item.durationLabel)
                        HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                        DetailRow("Format", item.kind.uppercase())
                    }
                }
            }
            item.note?.let { note ->
                item {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(
                            Icons.Default.Info,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(Modifier.width(Tokens.spacingSm))
                        Text(
                            note,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BackButton(onBack: () -> Unit) {
    IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
    }
}

@Composable
private fun SkeletonColumn(modifier: Modifier = Modifier) {
    Column(
        modifier.padding(Tokens.spacingLg),
        verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
    ) {
        repeat(3) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceContainer,
                        RoundedCornerShape(Tokens.radiusLg),
                    ),
            )
        }
    }
}

@Composable
private fun EmptyState(
    message: String,
    modifier: Modifier = Modifier,
    onAction: (() -> Unit)? = null,
) {
    Column(
        modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (onAction != null) {
            Spacer(Modifier.height(Tokens.spacingMd))
            Button(onClick = onAction) { Text("Browse Events") }
        }
    }
}

@Composable
private fun ErrorState(onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Default.Warning,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(Tokens.spacingMd))
        Text("Something went wrong", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(Tokens.spacingMd))
        Button(onClick = onRetry) { Text("Retry") }
    }
}

/** `split_decision` reads as a database column; `Split decision` reads as a result. */
private val String.displayMethod: String
    get() = replace('_', ' ').replaceFirstChar { it.uppercase() }

/** Dataset dates are plain `yyyy-MM-dd`; the raw form reads as a database column. */
private val String.displayDate: String
    get() = runCatching {
        LocalDate.parse(this).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
    }.getOrDefault(this)

private val MediaItem.durationLabel: String
    get() {
        val minutes = durationSeconds / 60
        val seconds = durationSeconds % 60
        return "%d:%02d".format(minutes, seconds)
    }
