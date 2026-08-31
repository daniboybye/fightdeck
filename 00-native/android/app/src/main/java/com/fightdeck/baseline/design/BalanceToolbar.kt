package com.fightdeck.baseline.design

import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

@Composable
fun BalanceMenuAction(
    balanceLabel: String,
    onDeposit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    TextButton(onClick = { expanded = true }, modifier = modifier.defaultMinSize(minHeight = Tokens.minTapTarget)) {
        Text(
            balanceLabel,
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.sp,
        )
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        DropdownMenuItem(
            text = { Text("Deposit") },
            leadingIcon = { Icon(Icons.Default.Add, contentDescription = null) },
            onClick = {
                expanded = false
                onDeposit()
            },
        )
    }
}
