package com.fightdeck.swiftcore.ui

import android.net.Uri
import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
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
import coil3.compose.SubcomposeAsyncImage
import com.fightdeck.swiftcore.core.BetMode
import com.fightdeck.swiftcore.core.BetSlip
import com.fightdeck.swiftcore.core.Money
import com.fightdeck.swiftcore.core.SlipState
import com.fightdeck.swiftcore.data.Bout
import com.fightdeck.swiftcore.data.Corner
import com.fightdeck.swiftcore.data.Event
import com.fightdeck.swiftcore.data.Fighter
import com.fightdeck.swiftcore.data.MediaItem
import com.fightdeck.swiftcore.data.NewsItem
import com.fightdeck.swiftcore.design.BalanceMenuAction
import com.fightdeck.swiftcore.design.Tokens
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
            BootstrapState.Ready -> FightDeckMain(viewModel)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FightDeckMain(viewModel: MainViewModel) {
        val slip by viewModel.slip.collectAsStateWithLifecycle()
        val balance by viewModel.balance.collectAsStateWithLifecycle()
        var showDepositSheet by remember { mutableStateOf(false) }
        val onDepositFromToolbar = { showDepositSheet = true }

        var selectedTab by remember { mutableIntStateOf(UPCOMING_TAB) }
        val upcomingNav = rememberNavController()
        val pastNav = rememberNavController()
        val slipNav = rememberNavController()
        // The bar is a shortcut into the slip on every tab while selections exist, and it
        // hides while the deposit sheet is open — matching iOS tabViewBottomAccessory.
        val showsSlipToolbar = slip.selections.isNotEmpty() && !showDepositSheet

        Scaffold(
            modifier = Modifier.fillMaxSize(),
            containerColor = Tokens.background,
            bottomBar = {
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
            },
        ) { padding ->
            Box(Modifier.padding(padding)) {
                when (selectedTab) {
                    UPCOMING_TAB -> EventsNavHost(
                        nav = upcomingNav,
                        mode = EventMode.Upcoming,
                        viewModel = viewModel,
                        balance = balance,
                        onDeposit = onDepositFromToolbar,
                        modifier = Modifier.fillMaxSize(),
                    )

                    PAST_TAB -> EventsNavHost(
                        nav = pastNav,
                        mode = EventMode.Past,
                        viewModel = viewModel,
                        balance = balance,
                        onDeposit = onDepositFromToolbar,
                        modifier = Modifier.fillMaxSize(),
                    )

                    else -> SlipNavHost(
                        slipNav = slipNav,
                        viewModel = viewModel,
                        balance = balance,
                        onDeposit = onDepositFromToolbar,
                        onBrowseEvents = { selectedTab = UPCOMING_TAB },
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }

        if (showDepositSheet) {
            ModalBottomSheet(onDismissRequest = { showDepositSheet = false }) {
                DepositScreen(
                    balance = balance,
                    onDone = { amount ->
                        viewModel.deposit(amount)
                        showDepositSheet = false
                    },
                    onBack = { showDepositSheet = false },
                )
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
                FighterProfileScreen(
                    fighter,
                    viewModel,
                    balance = balance,
                    onDeposit = onDeposit,
                    onBack = { nav.popBackStack() },
                )
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

@Composable
private fun SlipNavHost(
    slipNav: NavHostController,
    viewModel: MainViewModel,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onBrowseEvents: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val slip by viewModel.slip.collectAsStateWithLifecycle()
    val fighters by viewModel.fighters.collectAsStateWithLifecycle()
    val events by viewModel.events.collectAsStateWithLifecycle()
    val placedMessage by viewModel.betPlacedMessage.collectAsStateWithLifecycle()

    NavHost(navController = slipNav, startDestination = "slip", modifier = modifier) {
        composable("slip") {
            BetSlipScreen(
                viewModel = viewModel,
                slip = slip,
                balance = balance,
                fighters = (fighters as? LoadState.Loaded)?.value.orEmpty(),
                events = (events as? LoadState.Loaded)?.value.orEmpty(),
                placedMessage = placedMessage,
                onBrowseEvents = onBrowseEvents,
                onDeposit = onDeposit,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EventListScreen(
    state: LoadState<List<Event>>,
    news: LoadState<List<NewsItem>>,
    media: LoadState<List<MediaItem>>,
    mode: EventMode,
    viewModel: MainViewModel,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onRetry: () -> Unit,
    onEventClick: (Event) -> Unit,
    onArticleClick: (NewsItem) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
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
                actions = {
                    BalanceMenuAction(
                        balanceLabel = Money.formatCurrency(balance),
                        onDeposit = onDeposit,
                    )
                },
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
                    val clips = (media as? LoadState.Loaded)?.value.orEmpty()
                    if (clips.isNotEmpty()) {
                        item {
                            SectionHeader("Video")
                        }
                        items(clips, key = { it.id }) { clip ->
                            VideoCard(
                                item = clip,
                                eventName = state.value.firstOrNull { it.id == clip.eventId }?.name.orEmpty(),
                                posterUrl = viewModel.imageUrl(clip.poster),
                                onClick = { onVideoClick(clip) },
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
private fun RemoteImage(
    url: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
) {
    if (url == null) {
        Box(
            modifier
                .background(MaterialTheme.colorScheme.surfaceContainerHigh),
        )
        return
    }
    SubcomposeAsyncImage(
        model = url,
        contentDescription = null,
        modifier = modifier,
        contentScale = contentScale,
        loading = {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceContainerHigh),
            )
        },
    )
}

@Composable
private fun VideoCard(
    item: MediaItem,
    eventName: String,
    posterUrl: String?,
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
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(Tokens.radiusMd)),
            ) {
                RemoteImage(
                    url = posterUrl,
                    modifier = Modifier.fillMaxSize(),
                )
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .size(44.dp),
                )
                Surface(
                    color = Color.Black.copy(alpha = 0.6f),
                    shape = RoundedCornerShape(percent = 50),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(Tokens.spacingSm),
                ) {
                    Text(
                        item.durationLabel,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier.padding(
                            horizontal = Tokens.spacingSm,
                            vertical = Tokens.spacingXs,
                        ),
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Tokens.spacingXs)) {
                if (eventName.isNotEmpty()) {
                    Text(
                        eventName.uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = Tokens.accent,
                    )
                }
                Text(item.title, style = MaterialTheme.typography.titleMedium, maxLines = 2)
            }
        }
    }
}

@Composable
private fun PrimaryActionButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.fixedActionHeight(Tokens.primaryActionHeight),
        shape = RoundedCornerShape(percent = 50),
        contentPadding = PaddingValues(horizontal = Tokens.secondaryActionPadding),
        colors = ButtonDefaults.buttonColors(
            containerColor = Tokens.accent,
            contentColor = Tokens.onAccent,
            disabledContainerColor = Tokens.accent.copy(alpha = 0.38f),
            disabledContentColor = Tokens.onAccent.copy(alpha = 0.38f),
        ),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
    }
}

@Composable
private fun SecondaryActionButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.fixedActionHeight(Tokens.secondaryActionHeight),
        shape = RoundedCornerShape(percent = 50),
        contentPadding = PaddingValues(horizontal = Tokens.secondaryActionPadding),
        colors = ButtonDefaults.buttonColors(
            containerColor = Tokens.accent,
            contentColor = Tokens.onAccent,
        ),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
    }
}

@Composable
private fun KeyboardDoneButton(onClick: () -> Unit) {
    FilledTonalButton(
        onClick = onClick,
        modifier = Modifier.fixedActionHeight(Tokens.secondaryActionHeight),
        shape = RoundedCornerShape(percent = 50),
        contentPadding = PaddingValues(horizontal = Tokens.secondaryActionPadding),
    ) {
        Text("Done", style = MaterialTheme.typography.titleMedium, color = Tokens.accent)
    }
}

@Composable
private fun PresetChipButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    FilledTonalButton(
        onClick = onClick,
        modifier = modifier
            .fixedActionHeight(Tokens.secondaryActionHeight)
            .fillMaxWidth(),
        shape = RoundedCornerShape(percent = 50),
        contentPadding = PaddingValues(horizontal = Tokens.spacingSm),
    ) {
        Text(title, color = Tokens.accent, style = MaterialTheme.typography.labelLarge)
    }
}

@Composable
private fun LinkRowButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    TextButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .fixedActionHeight(Tokens.minTapTarget),
        contentPadding = PaddingValues(0.dp),
        shape = RoundedCornerShape(Tokens.radiusMd),
    ) {
        Text(
            title,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Start,
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}

@Composable
private fun BetPlacedState(message: String, onBrowseEvents: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Default.CheckCircle,
            contentDescription = null,
            tint = Tokens.positive,
            modifier = Modifier.size(64.dp),
        )
        Spacer(Modifier.height(Tokens.spacingLg))
        Text("Bet placed", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(Tokens.spacingSm))
        Text(
            message,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = Tokens.spacingXl),
        )
        Spacer(Modifier.height(Tokens.spacingXl))
        SecondaryActionButton(
            title = "Browse Events",
            onClick = onBrowseEvents,
        )
    }
}

@Composable
private fun EventCard(event: Event, mode: EventMode, posterUrl: String?, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        RemoteImage(
            url = posterUrl,
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp),
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
private fun NewsCard(item: NewsItem, eventName: String, imageUrl: String?, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        RemoteImage(
            url = imageUrl,
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp),
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
    event: Event,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
    media: LoadState<List<MediaItem>>,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onBoutClick: (Bout) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = event.name, onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
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
                                .fillMaxWidth()
                                .heightIn(min = Tokens.minTapTarget)
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
    balance: BigDecimal? = null,
    onDeposit: (() -> Unit)? = null,
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
                actions = {
                    if (balance != null && onDeposit != null) {
                        BalanceMenuAction(
                            balanceLabel = Money.formatCurrency(balance),
                            onDeposit = onDeposit,
                        )
                    }
                },
            )
        },
        content = content,
    )
}

@Composable
private fun BoutRow(
    bout: Bout,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
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
    corner: Corner,
    bout: Bout,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
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
private fun FighterAvatar(url: String?, ring: Color, size: Dp) {
    if (url == null) {
        Box(
            Modifier
                .size(size)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape)
                .border(2.dp, ring, CircleShape),
        )
        return
    }
    SubcomposeAsyncImage(
        model = url,
        contentDescription = null,
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape)
            .border(2.dp, ring, CircleShape),
        contentScale = ContentScale.Crop,
        loading = {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceContainerHigh),
            )
        },
    )
}

@Composable
private fun OddsChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val chipModifier = Modifier.defaultMinSize(minWidth = 64.dp, minHeight = Tokens.minTapTarget)
    val contentPadding = PaddingValues(horizontal = Tokens.spacingMd)
    if (selected) {
        Button(
            onClick = onClick,
            shape = RoundedCornerShape(Tokens.radiusMd),
            modifier = chipModifier,
            contentPadding = contentPadding,
        ) {
            Text(label, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        }
    } else {
        FilledTonalButton(
            onClick = onClick,
            shape = RoundedCornerShape(Tokens.radiusMd),
            modifier = chipModifier,
            contentPadding = contentPadding,
        ) {
            Text(
                label,
                fontWeight = FontWeight.SemiBold,
                color = Tokens.accent,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun BoutDetailScreen(
    bout: Bout,
    mode: EventMode,
    slip: BetSlip,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onFighterClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(
        title = bout.weightClass.displayMethod,
        onBack = onBack,
        balance = balance,
        onDeposit = onDeposit,
    ) { padding ->
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
    corner: Corner,
    ring: Color,
    viewModel: MainViewModel,
    fighters: List<Fighter>,
    onClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = Tokens.minTapTarget)
            .clickable { onClick(corner.fighterId) },
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
private fun TaleOfTheTape(bout: Bout, fighters: List<Fighter>) {
    fun of(id: String): Fighter? = fighters.firstOrNull { it.id == id }
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
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            left ?: "—",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Start,
            softWrap = true,
            maxLines = 2,
            overflow = TextOverflow.Visible,
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
            softWrap = true,
            maxLines = 2,
            overflow = TextOverflow.Visible,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun FighterProfileScreen(
    fighter: Fighter,
    viewModel: MainViewModel,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = fighter.name, onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
        ) {
            item {
                Box {
                    RemoteImage(
                        url = viewModel.imageUrl(fighter.portrait),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(320.dp),
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
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = "Article", onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(
                top = padding.calculateTopPadding(),
                bottom = Tokens.spacingXl,
            ),
        ) {
            item {
                RemoteImage(
                    url = viewModel.imageUrl(item.heroImage),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp),
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
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = Tokens.minTapTarget)
                            .clickable { onVideoClick(clip) },
                    )
                }
            }
        }
    }
}

@Composable
private fun VideoScreen(
    item: MediaItem,
    balance: BigDecimal,
    onDeposit: () -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(title = "Video", onBack = onBack, balance = balance, onDeposit = onDeposit) { padding ->
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
                if (item.kind == "hls") {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(Tokens.radiusMd),
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(16f / 9f),
                    ) {
                        Column(
                            Modifier
                                .fillMaxSize()
                                .padding(Tokens.spacingLg),
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Text(
                                "HLS is not supported by VideoView",
                                style = MaterialTheme.typography.titleMedium,
                            )
                            Text(
                                item.note ?: "This clip requires a streaming engine beyond the platform player.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                } else {
                    var playbackError by remember(item.id) { mutableStateOf<String?>(null) }
                    if (playbackError != null) {
                        Text(playbackError!!, color = Tokens.negative)
                    } else {
                        AndroidView(
                            factory = { context ->
                                VideoView(context).apply {
                                    setVideoURI(Uri.parse(item.url))
                                    setMediaController(
                                        MediaController(context).also { controller ->
                                            controller.setAnchorView(this)
                                        },
                                    )
                                    setOnPreparedListener { mediaPlayer ->
                                        mediaPlayer.setVolume(1f, 1f)
                                        start()
                                    }
                                    setOnErrorListener { _, what, extra ->
                                        post {
                                            playbackError = "Cannot start playback ($what/$extra)"
                                        }
                                        true
                                    }
                                }
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .aspectRatio(16f / 9f)
                                .clip(RoundedCornerShape(Tokens.radiusMd)),
                            onRelease = { it.stopPlayback() },
                        )
                    }
                }
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BetSlipScreen(
    viewModel: MainViewModel,
    slip: BetSlip,
    balance: BigDecimal,
    fighters: List<Fighter>,
    events: List<Event>,
    placedMessage: String?,
    onBrowseEvents: () -> Unit,
    onDeposit: () -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(rememberTopAppBarState())
    val focusManager = LocalFocusManager.current
    var stakeFocused by remember { mutableStateOf(false) }
    val state = viewModel.slipState

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("Bet Slip", style = MaterialTheme.typography.headlineMedium) },
                scrollBehavior = scrollBehavior,
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    BalanceMenuAction(
                        balanceLabel = Money.formatCurrency(balance),
                        onDeposit = onDeposit,
                    )
                },
            )
        },
        bottomBar = {
            if (slip.selections.isNotEmpty()) {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceContainer,
                    modifier = Modifier
                        .navigationBarsPadding()
                        .imePadding(),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = Tokens.spacingLg)
                            .padding(top = Tokens.spacingSm, bottom = Tokens.actionBarGap),
                        horizontalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        PrimaryActionButton(
                            title = "Place bet",
                            onClick = viewModel::placeBet,
                            enabled = state.errors.isEmpty(),
                            modifier = Modifier.weight(1f),
                        )
                        AnimatedVisibility(visible = stakeFocused) {
                            KeyboardDoneButton { focusManager.clearFocus() }
                        }
                    }
                }
            }
        },
    ) { padding ->
        val screenState = when {
            slip.selections.isNotEmpty() -> 0
            placedMessage != null -> 1
            else -> 2
        }
        AnimatedContent(
            targetState = screenState,
            transitionSpec = {
                (scaleIn(initialScale = 0.92f) + fadeIn()) togetherWith
                    (scaleOut(targetScale = 0.92f) + fadeOut())
            },
            label = "slipContent",
            modifier = Modifier.padding(padding),
        ) { contentState ->
            when (contentState) {
                0 -> LazyColumn(
                    contentPadding = PaddingValues(
                        start = Tokens.spacingLg,
                        end = Tokens.spacingLg,
                        top = padding.calculateTopPadding(),
                        bottom = pinnedScrollBottomInset(padding.calculateBottomPadding()),
                    ),
                    verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
                ) {
                    item {
                        SectionHeader(if (slip.mode == BetMode.accumulator) "Accumulator" else "Single")
                    }
                    items(slip.selections, key = { "${it.boutId}-${it.fighterId}" }) { selection ->
                        val name = fighters.firstOrNull { it.id == selection.fighterId }?.name
                            ?: selection.fighterId
                        val event = events.firstOrNull { event ->
                            event.bouts.any { it.id == selection.boutId }
                        }
                        val opponentBout = event?.bouts?.firstOrNull { it.id == selection.boutId }
                        val opponentName = opponentBout?.let { bout ->
                            when (selection.fighterId) {
                                bout.redCorner.fighterId -> bout.blueCorner.name
                                bout.blueCorner.fighterId -> bout.redCorner.name
                                else -> "—"
                            }
                        } ?: "—"
                        Card(
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                            ),
                            shape = RoundedCornerShape(Tokens.radiusLg),
                        ) {
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .padding(Tokens.spacingLg),
                                verticalAlignment = Alignment.Top,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(name, style = MaterialTheme.typography.bodyLarge)
                                    Text(
                                        "vs $opponentName · ${event?.name ?: "—"}",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                Text(
                                    Money.format(selection.odds),
                                    color = Tokens.accent,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.padding(start = Tokens.spacingMd),
                                )
                                IconButton(onClick = {
                                    viewModel.removeSelection(selection.boutId, selection.fighterId)
                                }) {
                                    Icon(Icons.Default.Close, contentDescription = "Remove")
                                }
                            }
                        }
                    }
                    item { SectionHeader("Stake") }
                    item {
                        OutlinedTextField(
                            value = slip.stake.toPlainString(),
                            onValueChange = { viewModel.updateStake(Money.parse(it.ifBlank { "0" })) },
                            label = { Text("Amount") },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Decimal,
                                imeAction = ImeAction.Done,
                            ),
                            keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                            modifier = Modifier
                                .fillMaxWidth()
                                .onFocusChanged { stakeFocused = it.isFocused },
                        )
                    }
                    item {
                        Row(horizontalArrangement = Arrangement.spacedBy(Tokens.spacingSm)) {
                            listOf(5, 10, 25, 50).forEach { chip ->
                                PresetChipButton(
                                    title = "€$chip",
                                    onClick = { viewModel.updateStake(BigDecimal(chip)) },
                                    modifier = Modifier.weight(1f),
                                )
                            }
                        }
                    }
                    item { SummaryBlock(state) }
                    items(state.errors, key = { it.code }) { error ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Default.Warning,
                                contentDescription = null,
                                tint = Tokens.negative,
                                modifier = Modifier.size(16.dp),
                            )
                            Spacer(Modifier.width(Tokens.spacingSm))
                            Text(
                                error.code.displayMethod,
                                color = Tokens.negative,
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                    }
                    item { SectionHeader("Deposit") }
                    item {
                        Card(
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                            ),
                            shape = RoundedCornerShape(Tokens.radiusLg),
                        ) {
                            Column(
                                Modifier.padding(Tokens.spacingLg),
                                verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
                            ) {
                                DetailRow("Balance", Money.formatCurrency(balance))
                                LinkRowButton(title = "Add funds", onClick = onDeposit)
                            }
                        }
                    }
                }
                1 -> BetPlacedState(placedMessage.orEmpty(), onBrowseEvents, Modifier.fillMaxSize())
                else -> EmptyState("No selections yet", Modifier.fillMaxSize(), onBrowseEvents)
            }
        }
    }
}

@Composable
private fun SummaryBlock(state: SlipState) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        ) {
            DetailRow("Total stake", Money.formatCurrency(state.totalStake))
            state.combinedOddsDisplay?.let { DetailRow("Combined odds", Money.format(it)) }
            DetailRow("Potential return", Money.formatCurrency(state.potentialReturn))
            DetailRow("Potential profit", Money.formatCurrency(state.potentialProfit))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DepositScreen(balance: BigDecimal, onDone: (BigDecimal) -> Unit, onBack: () -> Unit) {
    var amountText by remember { mutableStateOf("") }
    var method by remember { mutableStateOf(DepositMethod.Card) }
    var didSucceed by remember { mutableStateOf(false) }
    var amountFocused by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    val amount = Money.parse(amountText.ifBlank { "0" })
    val validationMessage = when {
        amountText.isBlank() -> null
        amount < BigDecimal("10") -> "Minimum deposit is €10"
        amount > BigDecimal("2000") -> "Maximum deposit is €2,000"
        else -> null
    }
    val fee = Money.money(amount.multiply(method.feeRate))

    Scaffold(
        containerColor = Tokens.background,
        topBar = {
            TopAppBar(
                title = { Text(if (didSucceed) "Confirmed" else "Deposit") },
                // The money has already moved by the time this screen appears, so going back to
                // the amount field would offer to spend it a second time.
                navigationIcon = { if (!didSucceed) BackButton(onBack) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        bottomBar = {
            if (!didSucceed) {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceContainer,
                    modifier = Modifier
                        .navigationBarsPadding()
                        .imePadding(),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = Tokens.spacingLg)
                            .padding(top = Tokens.spacingSm, bottom = Tokens.actionBarGap),
                        horizontalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        PrimaryActionButton(
                            title = "Confirm deposit",
                            onClick = { didSucceed = true },
                            enabled = validationMessage == null && amountText.isNotBlank(),
                            modifier = Modifier.weight(1f),
                        )
                        AnimatedVisibility(visible = amountFocused) {
                            KeyboardDoneButton { focusManager.clearFocus() }
                        }
                    }
                }
            }
        },
    ) { padding ->
        if (didSucceed) {
            AnimatedContent(
                targetState = true,
                transitionSpec = {
                    (scaleIn(initialScale = 0.92f) + fadeIn()) togetherWith fadeOut()
                },
                label = "depositSuccess",
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .padding(Tokens.spacingXl),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(Tokens.spacingLg, Alignment.CenterVertically),
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = Tokens.positive,
                        modifier = Modifier.size(64.dp),
                    )
                    Text("Deposit successful", style = MaterialTheme.typography.headlineSmall)
                    Text(
                        "New balance: ${Money.formatCurrency(balance.add(amount))}",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    SecondaryActionButton(
                        title = "Done",
                        onClick = { onDone(amount) },
                    )
                }
            }
            return@Scaffold
        }

        LazyColumn(
            contentPadding = PaddingValues(
                start = Tokens.spacingLg,
                end = Tokens.spacingLg,
                top = padding.calculateTopPadding(),
                bottom = pinnedScrollBottomInset(padding.calculateBottomPadding()),
            ),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            item { SectionHeader("Amount") }
            item {
                OutlinedTextField(
                    value = amountText,
                    onValueChange = { amountText = it },
                    label = { Text("€0.00") },
                    singleLine = true,
                    isError = validationMessage != null,
                    supportingText = validationMessage?.let { { Text(it) } },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Decimal,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                    modifier = Modifier
                        .fillMaxWidth()
                        .onFocusChanged { amountFocused = it.isFocused },
                )
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(Tokens.spacingSm)) {
                    listOf("10", "25", "50", "100").forEach { chip ->
                        PresetChipButton(
                            title = "€$chip",
                            onClick = { amountText = chip },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
            item { SectionHeader("Method") }
            items(DepositMethod.entries, key = { it.name }) { item ->
                ListItem(
                    headlineContent = { Text(item.title) },
                    supportingContent = { Text(item.feeNote) },
                    leadingContent = {
                        RadioButton(selected = method == item, onClick = { method = item })
                    },
                    colors = ListItemDefaults.colors(
                        containerColor = MaterialTheme.colorScheme.surfaceContainer,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = Tokens.minTapTarget)
                        .clip(RoundedCornerShape(Tokens.radiusLg))
                        .clickable { method = item },
                )
            }
            item { SectionHeader("Summary") }
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
                    shape = RoundedCornerShape(Tokens.radiusLg),
                ) {
                    Column(
                        Modifier.padding(Tokens.spacingLg),
                        verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
                    ) {
                        DetailRow("Amount", Money.formatCurrency(amount))
                        DetailRow("Method", method.title)
                        DetailRow("Fee", Money.formatCurrency(fee))
                        DetailRow("Total", Money.formatCurrency(amount.add(fee)))
                        DetailRow("New balance", Money.formatCurrency(balance.add(amount)))
                    }
                }
            }
        }
    }
}

private enum class DepositMethod(val title: String, val feeNote: String, val feeRate: BigDecimal) {
    Card("Card", "Instant · 0% fee", BigDecimal.ZERO),
    Bank("Bank transfer", "1–2 days · 0% fee", BigDecimal.ZERO),
    Wallet("Wallet", "Instant · 1% fee", BigDecimal("0.01")),
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
            SecondaryActionButton(
                title = "Browse Events",
                onClick = onAction,
            )
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
        SecondaryActionButton(
            title = "Retry",
            onClick = onRetry,
        )
    }
}

private fun Modifier.fixedActionHeight(height: Dp = Tokens.primaryActionHeight): Modifier =
    defaultMinSize(minWidth = 0.dp, minHeight = 0.dp)
        .heightIn(max = height)
        .height(height)

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
