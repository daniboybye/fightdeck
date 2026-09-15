package com.fightdeck.rust.ui

import android.app.PictureInPictureParams
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.util.Rational
import android.widget.MediaController
import android.widget.VideoView
import androidx.activity.compose.LocalActivity
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
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
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
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
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
import com.fightdeck.rust.core.FightCoreDisplay
import com.fightdeck.rust.data.MediaItem
import com.fightdeck.rust.data.NewsItem
import com.fightdeck.rust.design.BalanceMenuAction
import com.fightdeck.rust.design.Tokens
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.delay
import uniffi.fightevents.BoutSummary
import uniffi.fightevents.CornerSummary
import uniffi.fightevents.EventCatalog
import uniffi.fightevents.EventSummary
import uniffi.fightevents.FighterSummary
import uniffi.fightslip.BetSlipRecord
import uniffi.fightslip.SlipStateRecord
import uniffi.fightslip.betTypeTitle
import uniffi.fightslip.validationErrorCode

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

/** How often playback position is sampled, so the floating window can pick the clip back up. */
private const val POSITION_SAMPLE_MS = 500L

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
            BootstrapState.Ready -> FightDeckMain(viewModel = viewModel)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FightDeckMain(viewModel: MainViewModel) {
        val slip by viewModel.slip.collectAsStateWithLifecycle()
        val slipState by viewModel.slipState.collectAsStateWithLifecycle()
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
                // Nothing but the picture belongs in the floating window.
                if (!isInFloatingWindow()) {
                    Column {
                        // In the bottom bar rather than the floating-action slot: the slot
                        // floats over the content, and this bar has to be part of the scroll
                        // insets so it never covers the last row.
                        if (showsSlipToolbar) {
                            BetSlipToolbar(
                                legCount = slip.selections.size,
                                potentialReturn = FightCoreDisplay.formatCurrencyAmount(
                                    slipState.potentialReturn,
                                ),
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
            // The slip screen nests its own scaffold in here and lifts its action bar over the
            // keyboard. Consuming the padding this scaffold already spent means that lift is
            // measured from the space the tab content actually gets, not from the window edge —
            // otherwise the keyboard inset lands on top of the tab bar's height and the buttons
            // float a tab bar's worth above the keys.
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
                        onDeposit = onDepositFromToolbar,
                        onBrowseEvents = { selectedTab = UPCOMING_TAB },
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }

        if (showDepositSheet) {
            DepositSheet(
                balance = balance,
                onDeposit = { amount ->
                    viewModel.deposit(amount)
                    showDepositSheet = false
                },
                onDismiss = { showDepositSheet = false },
            )
        }
}

/**
 * A half-height sheet gives the keyboard the half it was using: the form's own bar clears the
 * keys correctly, but the sheet is not tall enough to show where it went, so the confirm button
 * lands below the sheet and the screen ends in a row of quick-amount chips. Going full height
 * when the keyboard arrives is what keeps the button — and the amount being typed — on screen.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DepositSheet(
    balance: String,
    onDeposit: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val keyboard = WindowInsets.ime.asPaddingValues().calculateBottomPadding()
    val sheetState = rememberModalBottomSheetState()
    LaunchedEffect(keyboard > 0.dp) {
        if (keyboard > 0.dp) {
            sheetState.expand()
        }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        DepositScreen(balance = balance, onDone = onDeposit, onClose = onDismiss)
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
    balance: String,
    onDeposit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val events by viewModel.events.collectAsStateWithLifecycle()
    val news by viewModel.news.collectAsStateWithLifecycle()
    val media by viewModel.media.collectAsStateWithLifecycle()
    // Collected here, not read through viewModel.isSelected(): a plain getter is invisible to
    // Compose, so an odds tap only showed up once something else forced a recomposition.
    val slip by viewModel.slip.collectAsStateWithLifecycle()
    val loadedEvents = (events as? LoadState.Loaded)?.value.orEmpty()

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
            val boutId = entry.arguments?.getString("boutId")
            val bout = boutId?.let { runCatching { viewModel.requireCatalog().bout(it) }.getOrNull() }
            if (bout != null) {
                BoutDetailScreen(
                    bout = bout,
                    mode = mode,
                    slip = slip,
                    viewModel = viewModel,
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
            val fighterId = entry.arguments?.getString("fighterId")
            val fighter = fighterId?.let { viewModel.fighter(it) }
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
                VideoScreen(
                    clip,
                    balance = balance,
                    onDeposit = onDeposit,
                    onBack = { nav.popBackStack() },
                )
            }
        }
    }
}

@Composable
private fun SlipNavHost(
    slipNav: NavHostController,
    viewModel: MainViewModel,
    onDeposit: () -> Unit,
    onBrowseEvents: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val slip by viewModel.slip.collectAsStateWithLifecycle()
    val balance by viewModel.balance.collectAsStateWithLifecycle()
    val placedMessage by viewModel.betPlacedMessage.collectAsStateWithLifecycle()

    val slipState by viewModel.slipState.collectAsStateWithLifecycle()

    NavHost(navController = slipNav, startDestination = "slip", modifier = modifier) {
        composable("slip") {
            BetSlipScreen(
                viewModel = viewModel,
                slip = slip,
                slipState = slipState,
                balance = balance,
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
    state: LoadState<List<EventSummary>>,
    news: LoadState<List<NewsItem>>,
    media: LoadState<List<MediaItem>>,
    mode: EventMode,
    viewModel: MainViewModel,
    balance: String,
    onDeposit: () -> Unit,
    onRetry: () -> Unit,
    onEventClick: (EventSummary) -> Unit,
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
                        balanceLabel = FightCoreDisplay.formatCurrencyAmount(balance),
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
                        posterUrl = viewModel.imageUrl(event.posterPath),
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
private fun EventCard(event: EventSummary, mode: EventMode, posterUrl: String?, onClick: () -> Unit) {
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
                event.locationLine,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${event.date.displayDate} · ${event.boutCount} fights",
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
    event: EventSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    media: LoadState<List<MediaItem>>,
    balance: String,
    onDeposit: () -> Unit,
    onBoutClick: (BoutSummary) -> Unit,
    onVideoClick: (MediaItem) -> Unit,
    onBack: () -> Unit,
) {
    val bouts = viewModel.requireCatalog().cardSections(event.id)
        .flatMap { it.bouts }
        .sortedBy { it.order }
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
            items(bouts, key = { it.id }) { bout ->
                BoutRow(bout, mode, slip, viewModel, onClick = { onBoutClick(bout) })
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
    balance: String,
    onDeposit: () -> Unit,
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
                    BalanceMenuAction(
                        balanceLabel = FightCoreDisplay.formatCurrencyAmount(balance),
                        onDeposit = onDeposit,
                    )
                },
            )
        },
        content = content,
    )
}

@Composable
private fun BoutRow(
    bout: BoutSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
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
            Text(
                bout.headline,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CornerLine(bout.red, bout, mode, slip, viewModel, Tokens.cornerRed)
            CornerLine(bout.blue, bout, mode, slip, viewModel, Tokens.cornerBlue)
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
                        bout.resultLine,
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
    corner: CornerSummary,
    bout: BoutSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    ring: Color,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
            FighterAvatar(viewModel.imageUrl(corner.portraitPath), ring, 40.dp)
            Spacer(Modifier.width(Tokens.spacingMd))
            Column {
                Text(corner.name, style = MaterialTheme.typography.bodyLarge)
                Text(
                    corner.recordDisplay,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (mode.showsOdds) {
            OddsChip(
                label = corner.oddsDecimal,
                selected = slip.selections.any {
                    it.boutId == bout.id && it.fighterId == corner.fighterId
                },
                onClick = {
                    viewModel.toggleSelection(bout, corner.fighterId, corner.oddsDecimal)
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
    bout: BoutSummary,
    mode: EventMode,
    slip: BetSlipRecord,
    viewModel: MainViewModel,
    balance: String,
    onDeposit: () -> Unit,
    onFighterClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    DetailScaffold(
        title = bout.weightClassDisplay,
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
                    FighterHero(bout.red, Tokens.cornerRed, viewModel, onFighterClick, Modifier.weight(1f))
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
                    FighterHero(bout.blue, Tokens.cornerBlue, viewModel, onFighterClick, Modifier.weight(1f))
                }
            }
            item { SectionHeader("Tale of the tape") }
            item { TaleOfTheTape(bout.id, viewModel.requireCatalog()) }
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
                            CornerLine(bout.red, bout, mode, slip, viewModel, Tokens.cornerRed)
                            CornerLine(bout.blue, bout, mode, slip, viewModel, Tokens.cornerBlue)
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
                            DetailRow("Winner", bout.winnerName, Tokens.positive)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Method", bout.resultMethod.displayMethod)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Detail", bout.resultDetail)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Ended", "Round ${bout.endRound} · ${bout.endTime}")
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
    corner: CornerSummary,
    ring: Color,
    viewModel: MainViewModel,
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
        FighterAvatar(viewModel.imageUrl(corner.portraitPath), ring, 88.dp)
        Text(
            corner.name,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            corner.recordDisplay,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun TaleOfTheTape(boutId: String, catalog: EventCatalog) {
    val tape = runCatching { catalog.taleOfTheTape(boutId) }.getOrNull()

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingMd),
        ) {
            tape?.rows?.forEach { TapeRow(it.red, it.label, it.blue) }
            tape?.edgeSummary?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
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
    fighter: FighterSummary,
    viewModel: MainViewModel,
    balance: String,
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
                        url = viewModel.imageUrl(fighter.portraitPath),
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
                            fighter.recordDisplay,
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
                            DetailRow("Record", fighter.recordDisplay)
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Wins", "${fighter.wins}")
                            HorizontalDivider(Modifier.padding(vertical = Tokens.spacingSm))
                            DetailRow("Losses", "${fighter.losses}")
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
                            DetailRow("Stance", fighter.stance ?: "—")
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
    balance: String,
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
    balance: String,
    onDeposit: () -> Unit,
    onBack: () -> Unit,
) {
    var playbackError by remember(item.id) { mutableStateOf<String?>(null) }
    // Not composition state: the replacement surface is composed before the old one is released,
    // so a snapshot value would still read zero and the clip would start over.
    val resumeAt = remember(item.id) { intArrayOf(0) }
    offerFloatingWindow(autoEnter = playbackError == null)

    if (isInFloatingWindow()) {
        // The window is the size of the picture, so the picture is all it shows.
        VideoSurface(
            item = item,
            resumeAt = resumeAt,
            showControls = false,
            onError = { playbackError = it },
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
        )
        return
    }

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
                val error = playbackError
                if (error != null) {
                    Text(error, color = Tokens.negative)
                } else {
                    VideoSurface(
                        item = item,
                        resumeAt = resumeAt,
                        showControls = true,
                        onError = { playbackError = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(16f / 9f)
                            .clip(RoundedCornerShape(Tokens.radiusMd)),
                    )
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

/**
 * VideoView owns its MediaPlayer and drops it when the surface goes away, so moving between this
 * screen and the floating window starts the clip again — from where it left off.
 */
@Composable
private fun VideoSurface(
    item: MediaItem,
    resumeAt: IntArray,
    showControls: Boolean,
    onError: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var player by remember { mutableStateOf<VideoView?>(null) }

    // The replacement surface is built before this one is torn down, so reading the position on
    // the way out is too late for it to be of any use. Sampling while the clip plays is not.
    LaunchedEffect(player) {
        val view = player ?: return@LaunchedEffect
        while (true) {
            delay(POSITION_SAMPLE_MS)
            if (view.isPlaying) resumeAt[0] = view.currentPosition
        }
    }

    AndroidView(
        factory = { context ->
            VideoView(context).apply {
                player = this
                setVideoURI(Uri.parse(item.url))
                if (showControls) {
                    setMediaController(
                        MediaController(context).also { controller ->
                            controller.setAnchorView(this)
                        },
                    )
                }
                setOnPreparedListener { mediaPlayer ->
                    mediaPlayer.setVolume(1f, 1f)
                    // VideoView.seekTo lands on the nearest keyframe, which on these clips is up
                    // to ten seconds back; the clip should carry on where it was, not before.
                    mediaPlayer.seekTo(resumeAt[0].toLong(), MediaPlayer.SEEK_CLOSEST)
                    start()
                }
                setOnErrorListener { _, what, extra ->
                    post { onError("Cannot start playback ($what/$extra)") }
                    true
                }
            }
        },
        modifier = modifier,
        onRelease = { view -> view.stopPlayback() },
    )
}

/**
 * Offers the system a floating window for when the app is minimised. Leaving the screen that
 * made the offer takes it back, so only video minimises this way.
 */
@Composable
private fun offerFloatingWindow(autoEnter: Boolean) {
    val activity = LocalActivity.current ?: return

    LaunchedEffect(activity, autoEnter) {
        activity.setPictureInPictureParams(floatingWindowParams(autoEnter))
    }
    DisposableEffect(activity) {
        onDispose { activity.setPictureInPictureParams(floatingWindowParams(autoEnter = false)) }
    }
}

/** Whether the app is in that floating window right now. */
@Composable
private fun isInFloatingWindow(): Boolean {
    val activity = LocalActivity.current ?: return false
    // Moving into the window resizes it, and a resize is a configuration change, which is what
    // brings this composable back here to ask again.
    val configuration = LocalConfiguration.current
    return remember(configuration) { activity.isInPictureInPictureMode }
}

private fun floatingWindowParams(autoEnter: Boolean): PictureInPictureParams {
    val params = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
    // Letting the system enter the window itself, rather than asking from onUserLeaveHint, is
    // what makes the swipe-to-home gesture animate into it. Android 12 and newer only.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        params.setAutoEnterEnabled(autoEnter)
    }
    return params.build()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BetSlipScreen(
    viewModel: MainViewModel,
    slip: BetSlipRecord,
    slipState: SlipStateRecord,
    balance: String,
    placedMessage: String?,
    onBrowseEvents: () -> Unit,
    onDeposit: () -> Unit,
) {
    val scrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(rememberTopAppBarState())
    val focusManager = LocalFocusManager.current
    var stakeFocused by remember { mutableStateOf(false) }
    val state = slipState

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
                        balanceLabel = FightCoreDisplay.formatCurrencyAmount(balance),
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
                        SectionHeader(betTypeTitle(slip.mode))
                    }
                    items(slip.selections, key = { "${it.boutId}-${it.fighterId}" }) { selection ->
                        val leg = viewModel.requireCatalog().legContext(selection.boutId, selection.fighterId)
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
                                    Text(leg.fighterName, style = MaterialTheme.typography.bodyLarge)
                                    Text(
                                        leg.subtitle,
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                Text(
                                    FightCoreDisplay.formatOdds(selection.odds),
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
                            value = slip.stake,
                            onValueChange = { viewModel.updateStake(it.ifBlank { "0" }) },
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
                                    onClick = {
                                        viewModel.updateStake(String.format("%.2f", chip.toDouble()))
                                    },
                                    modifier = Modifier.weight(1f),
                                )
                            }
                        }
                    }
                    item { SummaryBlock(state) }
                    items(state.errors, key = { validationErrorCode(it) }) { error ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Default.Warning,
                                contentDescription = null,
                                tint = Tokens.negative,
                                modifier = Modifier.size(16.dp),
                            )
                            Spacer(Modifier.width(Tokens.spacingSm))
                            Text(
                                validationErrorCode(error).displayMethod,
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
                                DetailRow("Balance", FightCoreDisplay.formatCurrencyAmount(balance))
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
private fun SummaryBlock(state: SlipStateRecord) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        shape = RoundedCornerShape(Tokens.radiusLg),
    ) {
        Column(
            Modifier.padding(Tokens.spacingLg),
            verticalArrangement = Arrangement.spacedBy(Tokens.spacingSm),
        ) {
            state.summaryRows.forEach { DetailRow(it.label, it.value) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DepositScreen(balance: String, onDone: (String) -> Unit, onClose: () -> Unit) {
    var amountText by remember { mutableStateOf("") }
    var method by remember { mutableStateOf(DepositMethod.Card) }
    var didSucceed by remember { mutableStateOf(false) }
    var amountFocused by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    val balanceAmount = runCatching { BigDecimal(balance) }.getOrDefault(BigDecimal.ZERO)
    val amount = runCatching { BigDecimal(amountText.ifBlank { "0" }) }.getOrDefault(BigDecimal.ZERO)
    val validationMessage = when {
        amountText.isBlank() -> null
        amount < BigDecimal("10") -> "Minimum deposit is €10"
        amount > BigDecimal("2000") -> "Maximum deposit is €2,000"
        else -> null
    }
    val fee = amount.multiply(method.feeRate).setScale(2, RoundingMode.HALF_UP)

    Scaffold(
        containerColor = Tokens.background,
        topBar = {
            TopAppBar(
                title = { Text(if (didSucceed) "Confirmed" else "Deposit") },
                // The money has already moved by the time the confirmation shows, so that screen
                // leaves through Done only: closing it would offer to spend the deposit twice.
                navigationIcon = { if (!didSucceed) CloseButton(onClose) },
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
                        "New balance: ${formatDepositCurrency(balanceAmount.add(amount))}",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    SecondaryActionButton(
                        title = "Done",
                        onClick = { onDone(amount.setScale(2, RoundingMode.HALF_UP).toPlainString()) },
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
                    // A label would float into the outline and sit there restating an empty
                    // field. A placeholder leaves once it has been read, so it can spend its
                    // one appearance on the limits instead.
                    placeholder = { Text("€10 – €2,000") },
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
                        DetailRow("Amount", formatDepositCurrency(amount))
                        DetailRow("Method", method.title)
                        DetailRow("Fee", formatDepositCurrency(fee))
                        DetailRow("Total", formatDepositCurrency(amount.add(fee)))
                        DetailRow("New balance", formatDepositCurrency(balanceAmount.add(amount)))
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

private fun formatDepositCurrency(value: BigDecimal): String =
    FightCoreDisplay.formatCurrencyAmount(
        value.setScale(2, RoundingMode.HALF_UP).toPlainString(),
    )

@Composable
private fun BackButton(onBack: () -> Unit) {
    IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
    }
}

@Composable
private fun CloseButton(onClose: () -> Unit) {
    IconButton(onClick = onClose) {
        Icon(Icons.Default.Close, contentDescription = "Close")
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

private val String.displayMethod: String
    get() = uniffi.fightevents.humaniseCode(this)

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
