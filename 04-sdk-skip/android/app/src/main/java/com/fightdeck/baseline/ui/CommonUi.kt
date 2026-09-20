package com.fightdeck.baseline.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.SubcomposeAsyncImage
import com.fightdeck.baseline.design.BalanceMenuAction
import com.fightdeck.baseline.design.Tokens
import fight.deck.core.Money
import fight.deck.events.Display
import java.math.BigDecimal

@Composable
internal fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(top = Tokens.spacingLg, bottom = Tokens.spacingXs),
    )
}

@Composable
internal fun RemoteImage(
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
internal fun PrimaryActionButton(
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DetailScaffold(
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
internal fun FighterAvatar(url: String?, ring: Color, size: Dp) {
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
internal fun DetailRow(label: String, value: String, valueColor: Color = Color.Unspecified) {
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
private fun BackButton(onBack: () -> Unit) {
    IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
    }
}

@Composable
internal fun SkeletonColumn(modifier: Modifier = Modifier) {
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
internal fun EmptyState(
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
internal fun ErrorState(onRetry: () -> Unit, modifier: Modifier = Modifier) {
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

// The three formats below are the shared module's, reached through extensions so the call sites
// stay Kotlin-idiomatic. Each of these used to be a second implementation, and displayMethod's
// was not even equivalent: it title-cased only the first word where iOS title-cased every one.
internal val String.displayMethod: String
    get() = Display.humanise(this)

internal val String.displayDate: String
    get() = Display.eventDate(this)
