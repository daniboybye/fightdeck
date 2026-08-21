package com.fightdeck.baseline.ui

import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
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
import com.fightdeck.baseline.core.BetSlip
import com.fightdeck.baseline.core.FightCore
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

@Composable
fun FightDeckApp(viewModel: MainViewModel = viewModel()) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Tokens.accent,
            onPrimary = Tokens.onAccent,
            background = Tokens.background,
            surface = Tokens.surface,
        ),
    ) {
        val slip by viewModel.slip.collectAsStateWithLifecycle()

        var selectedTab by remember { mutableIntStateOf(0) }
        val upcomingNav = rememberNavController()
        val pastNav = rememberNavController()
        val slipNav = rememberNavController()
        val slipEntry by slipNav.currentBackStackEntryAsState()

        // The deposit flow is a single self-contained task; the tab bar would invite the user
        // to abandon it half-way.
        val onDeposit = slipEntry?.destination?.route == DEPOSIT_ROUTE

        Scaffold(
            modifier = Modifier
                .fillMaxSize()
                .background(Tokens.background)
                .windowInsetsPadding(WindowInsets.safeDrawing),
            containerColor = Tokens.background,
            bottomBar = {
                if (!onDeposit) {
                    Column {
                        // The bar exists to get you to the slip, so it is pure noise while the
                        // slip is already on screen.
                        if (slip.selections.isNotEmpty() && selectedTab != 2) {
                            BetSlipBar(
                                legCount = slip.selections.size,
                                potentialReturn = Money.formatCurrency(viewModel.slipState.potentialReturn),
                                onClick = { selectedTab = 2 },
                            )
                        }
                        NavigationBar(containerColor = Tokens.surface) {
                            NavigationBarItem(
                                selected = selectedTab == 0,
                                onClick = { selectedTab = 0 },
                                icon = { Text("🗓") },
                                label = { Text("Upcoming") },
                            )
                            NavigationBarItem(
                                selected = selectedTab == 1,
                                onClick = { selectedTab = 1 },
                                icon = { Text("🏆") },
                                label = { Text("Past") },
                            )
                            NavigationBarItem(
                                selected = selectedTab == 2,
                                onClick = { selectedTab = 2 },
                                icon = { Text("🧾") },
                                label = { Text("Slip") },
                            )
                        }
                    }
                }
            },
        ) { padding ->
            Box(Modifier.padding(padding)) {
                when (selectedTab) {
                    0 -> EventsNavHost(
                        nav = upcomingNav,
                        mode = EventMode.Upcoming,
                        viewModel = viewModel,
                        modifier = Modifier.fillMaxSize(),
                    )

                    1 -> EventsNavHost(
                        nav = pastNav,
                        mode = EventMode.Past,
                        viewModel = viewModel,
                        modifier = Modifier.fillMaxSize(),
                    )

                    else -> SlipNavHost(
                        slipNav = slipNav,
                        viewModel = viewModel,
                        onBrowseEvents = { selectedTab = 0 },
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }
    }
}

@Composable
private fun BetSlipBar(legCount: Int, potentialReturn: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.spacingLg, vertical = Tokens.spacingSm)
            .clickable(onClick = onClick),
        color = Tokens.surfaceElevated,
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Row(
            Modifier.padding(Tokens.spacingLg),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            val suffix = if (legCount == 1) "" else "s"
            Text("$legCount selection$suffix", color = Tokens.textPrimary)
            Text("Return $potentialReturn", color = Tokens.textPrimary, fontWeight = FontWeight.Bold)
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
    val loadedEvents = (events as? LoadState.Loaded)?.value.orEmpty()

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
                    viewModel = viewModel,
                    fighters = fighters,
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
                    viewModel = viewModel,
                    fighters = fighters,
                    onFighterClick = { nav.navigate("fighter/$it") },
                    onBack = { nav.popBackStack() },
                )
            }
        }
        composable(
            "fighter/{fighterId}",
            arguments = listOf(navArgument("fighterId") { type = NavType.StringType }),
        ) { entry ->
            val fighter = (fighters as? LoadState.Loaded)?.value
                ?.firstOrNull { it.id == entry.arguments?.getString("fighterId") }
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
    when (state) {
        LoadState.Loading -> SkeletonColumn()
        is LoadState.Empty -> EmptyState("No events")
        is LoadState.Error -> ErrorState(onRetry)
        is LoadState.Loaded -> LazyColumn(
            Modifier
                .padding(Tokens.spacingLg)
                .padding(bottom = Tokens.tabBarClearance),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            item {
                Text(mode.title, color = Tokens.textPrimary, fontSize = Tokens.fontHeadline, fontWeight = FontWeight.Bold)
            }
            items(state.value) { event ->
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
                        Text(
                            "News",
                            color = Tokens.textPrimary,
                            fontSize = Tokens.fontTitle,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(top = Tokens.spacingLg),
                        )
                    }
                    items(articles) { article ->
                        NewsCard(
                            item = article,
                            imageUrl = viewModel.imageUrl(article.heroImage),
                            onClick = { onArticleClick(article) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EventCard(event: EventItem, mode: EventMode, posterUrl: String, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Tokens.surface),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        ) {
            AsyncImage(
                model = posterUrl,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(Tokens.radiusMd)),
                contentScale = ContentScale.Crop,
            )
            Text(event.name, color = Tokens.textPrimary, fontSize = Tokens.fontTitle, fontWeight = FontWeight.Bold)
            Text("${event.venue} · ${event.city}", color = Tokens.textSecondary, fontSize = Tokens.fontBody)
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(event.date, color = Tokens.textSecondary, fontSize = Tokens.fontCaption)
                Text("${event.bouts.size} fights", color = Tokens.textSecondary, fontSize = Tokens.fontCaption)
                Text(
                    if (mode.showsResults) "FINISHED" else "OPEN",
                    color = if (mode.showsResults) Tokens.positive else Tokens.accent,
                    fontSize = Tokens.fontCaption,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun NewsCard(item: NewsItem, imageUrl: String, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Tokens.surface),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        ) {
            AsyncImage(
                model = imageUrl,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(Tokens.radiusMd)),
                contentScale = ContentScale.Crop,
            )
            Text(item.headline, color = Tokens.textPrimary, fontSize = Tokens.fontTitle, fontWeight = FontWeight.Bold)
            Text(item.body, color = Tokens.textSecondary, fontSize = Tokens.fontBody, maxLines = 2)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${item.readMinutes} min read", color = Tokens.textSecondary, fontSize = Tokens.fontCaption)
                Text(item.source, color = Tokens.accent, fontSize = Tokens.fontCaption)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EventDetailScreen(
    event: EventItem,
    mode: EventMode,
    viewModel: MainViewModel,
    fighters: LoadState<List<FighterItem>>,
    media: LoadState<List<MediaItem>>,
    onBoutClick: (BoutItem) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    Column {
        TopAppBar(
            title = { Text(event.name, color = Tokens.textPrimary, fontSize = Tokens.fontCallout) },
            navigationIcon = { BackButton(onBack) },
        )
        LazyColumn(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            items(event.bouts.sortedBy { it.order }) { bout ->
                BoutRow(bout, mode, viewModel, fighters, onClick = { onBoutClick(bout) })
            }
            if (mode.showsResults) {
                val clips = (media as? LoadState.Loaded)?.value.orEmpty().filter { it.eventId == event.id }
                items(clips) { clip ->
                    TextButton(onClick = { onVideoClick(clip) }) {
                        Text("Watch: ${clip.title}", color = Tokens.accent)
                    }
                }
            }
        }
    }
}

@Composable
private fun BoutRow(
    bout: BoutItem,
    mode: EventMode,
    viewModel: MainViewModel,
    fighters: LoadState<List<FighterItem>>,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Tokens.surface),
    ) {
        Column(Modifier.padding(Tokens.spacingLg), verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm)) {
            val title = bout.weightClass.uppercase() + if (bout.titleFight) " · TITLE" else ""
            Text("$title · ${bout.scheduledRounds} RNDS", color = Tokens.textSecondary, fontSize = Tokens.fontCaption)
            CornerLine(bout.redCorner, bout, mode, viewModel, fighters)
            CornerLine(bout.blueCorner, bout, mode, viewModel, fighters)
            if (mode.showsResults) {
                Text(
                    "✓ ${bout.result.winnerName} · ${bout.result.method.uppercase()} · R${bout.result.endRound} ${bout.result.endTime}",
                    color = Tokens.positive,
                    fontSize = Tokens.fontCaption,
                )
            }
        }
    }
}

@Composable
private fun CornerLine(
    corner: CornerItem,
    bout: BoutItem,
    mode: EventMode,
    viewModel: MainViewModel,
    fighters: LoadState<List<FighterItem>>,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            AsyncImage(
                model = viewModel.imageUrl("assets/fighters/${corner.fighterId}.jpg"),
                contentDescription = null,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape),
                contentScale = ContentScale.Crop,
            )
            Spacer(Modifier.size(Tokens.spacingMd))
            Column {
                Text(corner.name, color = Tokens.textPrimary, fontSize = Tokens.fontCallout)
                val record = (fighters as? LoadState.Loaded)?.value
                    ?.firstOrNull { it.id == corner.fighterId }?.record?.display ?: "—"
                Text(record, color = Tokens.textSecondary, fontSize = Tokens.fontCaption)
            }
        }
        if (mode.showsOdds) {
            OddsChip(
                label = corner.closingOdds.decimal,
                selected = viewModel.isSelected(bout.id, corner.fighterId),
                onClick = { viewModel.toggleSelection(bout, corner.fighterId, corner.closingOdds.decimal) },
            )
        }
    }
}

@Composable
private fun OddsChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        color = if (selected) Tokens.accent else Tokens.surfaceElevated,
        shape = RoundedCornerShape(Tokens.radiusMd),
    ) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = Tokens.spacingLg, vertical = Tokens.spacingMd),
            color = if (selected) Tokens.onAccent else Tokens.accent,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BoutDetailScreen(
    bout: BoutItem,
    mode: EventMode,
    viewModel: MainViewModel,
    fighters: LoadState<List<FighterItem>>,
    onFighterClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    Column {
        TopAppBar(
            title = { Text("Bout", color = Tokens.textPrimary) },
            navigationIcon = { BackButton(onBack) },
        )
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingLg),
        ) {
            Surface(color = Tokens.surfaceElevated, shape = RoundedCornerShape(Tokens.radiusLg)) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(Tokens.spacingXl),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    FighterHero(bout.redCorner, viewModel, onFighterClick)
                    Text("VS", color = Tokens.textSecondary)
                    FighterHero(bout.blueCorner, viewModel, onFighterClick)
                }
            }
            TaleOfTheTape(bout, fighters)
            if (mode.showsOdds) {
                CornerLine(bout.redCorner, bout, mode, viewModel, fighters)
                CornerLine(bout.blueCorner, bout, mode, viewModel, fighters)
            }
            if (mode.showsResults) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .background(Tokens.surface, RoundedCornerShape(Tokens.radiusLg))
                        .padding(Tokens.spacingLg),
                    verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
                ) {
                    Text("Result", color = Tokens.textPrimary, fontWeight = FontWeight.SemiBold)
                    Text(bout.result.winnerName, color = Tokens.positive)
                    Text("${bout.result.method.uppercase()} · ${bout.result.detail}", color = Tokens.textPrimary)
                    Text("Round ${bout.result.endRound} · ${bout.result.endTime}", color = Tokens.textPrimary)
                }
            }
        }
    }
}

@Composable
private fun FighterHero(corner: CornerItem, viewModel: MainViewModel, onClick: (String) -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable { onClick(corner.fighterId) },
    ) {
        AsyncImage(
            model = viewModel.imageUrl("assets/fighters/${corner.fighterId}.jpg"),
            contentDescription = null,
            modifier = Modifier
                .size(88.dp)
                .clip(CircleShape),
            contentScale = ContentScale.Crop,
        )
        Spacer(Modifier.size(Tokens.spacingSm))
        Text(corner.name, color = Tokens.textPrimary, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun TaleOfTheTape(bout: BoutItem, fighters: LoadState<List<FighterItem>>) {
    val loaded = (fighters as? LoadState.Loaded)?.value.orEmpty()
    fun of(id: String): FighterItem? = loaded.firstOrNull { it.id == id }
    val red = of(bout.redCorner.fighterId)
    val blue = of(bout.blueCorner.fighterId)

    Column(
        Modifier
            .fillMaxWidth()
            .background(Tokens.surface, RoundedCornerShape(Tokens.radiusLg))
            .padding(Tokens.spacingLg),
        verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
    ) {
        TapeRow(red?.record?.display, "RECORD", blue?.record?.display)
        TapeRow(red?.heightCm?.let { "$it cm" }, "HEIGHT", blue?.heightCm?.let { "$it cm" })
        TapeRow(red?.reachIn?.let { "$it in" }, "REACH", blue?.reachIn?.let { "$it in" })
        TapeRow(red?.stance, "STANCE", blue?.stance)
        TapeRow(red?.country, "COUNTRY", blue?.country)
    }
}

@Composable
private fun TapeRow(left: String?, label: String, right: String?) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(left ?: "—", color = Tokens.textPrimary, fontSize = Tokens.fontCallout)
        Text(label, color = Tokens.textSecondary, fontSize = Tokens.fontCaption, fontWeight = FontWeight.SemiBold)
        Text(right ?: "—", color = Tokens.textPrimary, fontSize = Tokens.fontCallout)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FighterProfileScreen(fighter: FighterItem, viewModel: MainViewModel, onBack: () -> Unit) {
    Column {
        TopAppBar(
            title = { Text(fighter.name, color = Tokens.textPrimary) },
            navigationIcon = { BackButton(onBack) },
        )
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            AsyncImage(
                model = viewModel.imageUrl(fighter.portrait),
                contentDescription = null,
                modifier = Modifier
                    .size(160.dp)
                    .clip(CircleShape),
                contentScale = ContentScale.Crop,
            )
            fighter.nickname?.let { Text("\"$it\"", color = Tokens.accent, fontSize = Tokens.fontTitle) }
            Text(fighter.record.display, color = Tokens.textPrimary, fontSize = Tokens.fontTitle)
            Text(fighter.country ?: "—", color = Tokens.textSecondary)
            Text(fighter.stance ?: "—", color = Tokens.textSecondary)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NewsArticleScreen(
    item: NewsItem,
    media: LoadState<List<MediaItem>>,
    viewModel: MainViewModel,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    Column {
        TopAppBar(
            title = { Text("Article", color = Tokens.textPrimary) },
            navigationIcon = { BackButton(onBack) },
        )
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            AsyncImage(
                model = viewModel.imageUrl(item.heroImage),
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .clip(RoundedCornerShape(Tokens.radiusLg)),
                contentScale = ContentScale.Crop,
            )
            Text(item.headline, color = Tokens.textPrimary, fontSize = Tokens.fontTitle, fontWeight = FontWeight.Bold)
            Text(item.body, color = Tokens.textPrimary, fontSize = Tokens.fontBody)
            Text("Source: ${item.source}", color = Tokens.textSecondary, fontSize = Tokens.fontCaption)
            (media as? LoadState.Loaded)?.value.orEmpty()
                .filter { it.eventId == item.eventId }
                .forEach { clip ->
                    TextButton(onClick = { onVideoClick(clip) }) {
                        Text("Watch: ${clip.title}", color = Tokens.accent)
                    }
                }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VideoScreen(item: MediaItem, onBack: () -> Unit) {
    Column {
        TopAppBar(
            title = { Text("Video", color = Tokens.textPrimary) },
            navigationIcon = { BackButton(onBack) },
        )
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
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
            Text(item.title, color = Tokens.textPrimary, fontSize = Tokens.fontTitle, fontWeight = FontWeight.Bold)
            val minutes = item.durationSeconds / 60
            val seconds = item.durationSeconds % 60
            Text("Duration: %d:%02d".format(minutes, seconds), color = Tokens.textSecondary)
            Text("Transcript placeholder — demo copy only.", color = Tokens.textSecondary)
        }
    }
}

@Composable
private fun BackButton(onBack: () -> Unit) {
    IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Tokens.textPrimary)
    }
}

@Composable
private fun SkeletonColumn() {
    Column(Modifier.padding(Tokens.spacingLg), verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd)) {
        repeat(3) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .background(Tokens.surface, RoundedCornerShape(Tokens.radiusLg)),
            )
        }
    }
}

@Composable
private fun EmptyState(message: String) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(message, color = Tokens.textSecondary)
    }
}

@Composable
private fun ErrorState(onRetry: () -> Unit) {
    Column(
        Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Something went wrong", color = Tokens.textSecondary)
        Spacer(Modifier.height(Tokens.spacingMd))
        Button(onClick = onRetry) { Text("Retry") }
    }
}
