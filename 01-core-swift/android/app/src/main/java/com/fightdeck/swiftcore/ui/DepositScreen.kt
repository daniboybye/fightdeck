package com.fightdeck.swiftcore.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fightdeck.fightcore.FightCoreJava
import com.fightdeck.swiftcore.design.Tokens

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DepositScreen(balance: String, onDone: (String) -> Unit, onClose: () -> Unit) {
    val methods = remember { FightCoreJava.depositMethods().toList() }
    var amountText by remember { mutableStateOf("") }
    var method by remember { mutableStateOf(methods.first()) }
    var didSucceed by remember { mutableStateOf(false) }
    var amountFocused by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current
    val quote = FightCoreJava.depositQuote(amountText, method.id, balance)
    val validationMessage = quote.validationMessage.ifEmpty { null }

    Scaffold(
        containerColor = Tokens.background,
        topBar = {
            // The money has already moved by the time the confirmation shows, so that screen
            // leaves through Done only: closing it would offer to spend the deposit twice. With
            // no way out and nothing to name — the confirmation says what happened, in the
            // middle of the screen where the eye already is — the bar has nothing left to hold.
            if (!didSucceed) {
                TopAppBar(
                    title = { Text("Deposit") },
                    navigationIcon = { CloseButton(onClose) },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                )
            }
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
                            enabled = quote.isConfirmable,
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
                        "New balance: ${quote.newBalanceDisplay}",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    SecondaryActionButton(
                        title = "Done",
                        onClick = { onDone(quote.amount) },
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
                    FightCoreJava.depositPresets().forEach { chip ->
                        PresetChipButton(
                            title = "€$chip",
                            onClick = { amountText = chip },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
            item { SectionHeader("Method") }
            items(methods, key = { it.id }) { item ->
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
                        DetailRow("Amount", quote.amountDisplay)
                        DetailRow("Method", method.title)
                        DetailRow("Fee", quote.feeDisplay)
                        DetailRow("Total", quote.totalDisplay)
                        DetailRow("New balance", quote.newBalanceDisplay)
                    }
                }
            }
        }
    }
}
