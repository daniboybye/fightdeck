package com.fightdeck.rust.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fightdeck.rust.core.FightCoreDisplay
import com.fightdeck.rust.design.BalanceMenuAction
import com.fightdeck.rust.design.Tokens
import uniffi.fightslip.BetSlipRecord
import uniffi.fightslip.SlipStateRecord
import uniffi.fightslip.betTypeTitle
import uniffi.fightslip.validationErrorCode

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
internal fun BetSlipScreen(
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
                // No fill behind the buttons. With one, the slip tab stacks three surface
                // tones — this strip, the selections pill above it and the navigation bar —
                // and the pill stops reading as part of the same bar. The action pill floats
                // on the page instead, which is what the React Native surface does.
                Row(
                    Modifier
                        .navigationBarsPadding()
                        .imePadding()
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
