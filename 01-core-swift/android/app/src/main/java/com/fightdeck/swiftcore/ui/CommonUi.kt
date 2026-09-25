package com.fightdeck.swiftcore.ui

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
import androidx.compose.material.icons.filled.Close
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.SubcomposeAsyncImage
import com.fightdeck.swiftcore.design.BalanceMenuAction
import com.fightdeck.swiftcore.design.Tokens
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

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
internal fun SecondaryActionButton(
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
internal fun KeyboardDoneButton(onClick: () -> Unit) {
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
internal fun PresetChipButton(
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DetailScaffold(
    title: String,
    onBack: () -> Unit,
    balanceLabel: String? = null,
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
                    if (balanceLabel != null && onDeposit != null) {
                        BalanceMenuAction(
                            balanceLabel = balanceLabel,
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
internal fun CloseButton(onClose: () -> Unit) {
    IconButton(onClick = onClose) {
        Icon(Icons.Default.Close, contentDescription = "Close")
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

internal fun Modifier.fixedActionHeight(height: Dp = Tokens.primaryActionHeight): Modifier =
    defaultMinSize(minWidth = 0.dp, minHeight = 0.dp)
        .heightIn(max = height)
        .height(height)

/** Dataset dates are plain `yyyy-MM-dd`; the raw form reads as a database column. */
internal val String.displayDate: String
    get() = runCatching {
        LocalDate.parse(this).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
    }.getOrDefault(this)
