# QuickSettings — Módulo Quickshell

Painel de Quick Settings para Quickshell/Hyprland.  
Segue os mesmos padrões visuais e de arquitetura do módulo `Volume`.

---

## Estrutura de arquivos

```
modules/default/quicksettings/
├── QuickSettings.qml           ← trigger da barra (ícone + indicador Wi-Fi)
├── QuickSettingsContent.qml    ← toda lógica e UI (orquestra subcomponentes)
├── QuickSettingsPanel.qml      ← PanelWindow com animação slide+clip
├── QuickSettingsPopup.qml      ← PopupWindow com animação fade+translate
├── qmldir
└── components/
    ├── QsToggleTile.qml        ← tile genérico reutilizável
    ├── QsVolumeSlider.qml      ← slider Pipewire (defaultAudioSink)
    ├── QsBrightnessSlider.qml  ← slider via brightnessctl
    ├── QsThermalSection.qml    ← seletor de perfil térmico
    ├── QsTabBar.qml            ← barra de abas estilo pill
    ├── QsTabNetworks.qml       ← lista de APs Wi-Fi
    ├── QsTabSystem.qml         ← hostname / kernel / uptime
    ├── QsTabTray.qml           ← ícones de system tray
    ├── QsFooter.qml            ← botões de energia com confirmação
    └── qmldir
```

---

## Integração com PanelWindow (uso típico)

```qml
// shell.qml ou bar.qml
import "modules/default/quicksettings"

// ── 1. Instanciar o Panel ──────────────────────────────────────────────────
QuickSettingsPanel {
    id: qsPanel
    barScreen:   screen          // Screen atual da barra
    barPosition: 1               // 1=top 2=right 3=bottom 4=left
    barSize:     32              // espessura da barra em px
    barMargin:   4               // gap entre barra e painel

    // Cores opcionais (os defaults já combinam com o tema padrão)
    colorAccent: "#ffb4a9"

    onCloseRequested: panelOpen = false
}

// ── 2. Instanciar o trigger na barra ──────────────────────────────────────
QuickSettings {
    isHorizontal: true
    barPosition:  1
    textColor:    "#e2e2e2"
    accentColor:  "#ffb4a9"
    onPanelRequested: qsPanel.panelOpen = !qsPanel.panelOpen
}
```

---

## Integração com PopupWindow

Use o `QuickSettingsPopup` quando a barra não precisa de `exclusiveZone`:

```qml
import "modules/default/quicksettings"

QuickSettingsPopup {
    id: qsPopup
    parentItem:   qsTrigger       // o item QuickSettings na barra
    popupAnchorY: "bottom"        // "top" para barras na parte inferior
    popupOffsetX: -280            // alinha à direita do trigger
    colorAccent:  "#ffb4a9"
    onCloseRequested: panelOpen = false
}

QuickSettings {
    id: qsTrigger
    onPanelRequested: qsPopup.panelOpen = !qsPopup.panelOpen
}
```

---

## Referência de propriedades

### QuickSettingsPanel / QuickSettingsPopup

| Propriedade    | Tipo  | Padrão    | Descrição                                       |
| -------------- | ----- | --------- | ----------------------------------------------- |
| `barScreen`    | var   | —         | **Obrigatório** — Screen da barra               |
| `barPosition`  | int   | —         | **Obrigatório** — 1=top 2=right 3=bottom 4=left |
| `barSize`      | int   | —         | **Obrigatório** — espessura da barra (px)       |
| `barMargin`    | int   | —         | **Obrigatório** — gap barra→painel (px)         |
| `panelOpen`    | bool  | `false`   | Controla abertura/fechamento                    |
| `colorPanelBg` | color | `#1f1f1f` | Fundo do painel                                 |
| `colorAccent`  | color | `#ffb4a9` | Cor de destaque                                 |
| `colorMuted`   | color | `#cf6679` | Cor de perigo/mudo                              |

### QuickSettings (trigger)

| Sinal              | Descrição                                         |
| ------------------ | ------------------------------------------------- |
| `panelRequested()` | Emitido ao clicar no trigger — abra o painel aqui |

---

## Adicionando novos toggles

Edite apenas o grid em `QuickSettingsContent.qml`:

```qml
// Adicione mais um QsToggleTile no GridLayout:
Qs.QsToggleTile {
    Layout.fillWidth:       true
    Layout.preferredHeight: 64
    icon:   "\uf0eb"          // qualquer ícone Nerd Font
    label:  "Meu Toggle"
    badge:  minhaVar ? "ativo" : ""
    active: minhaVar
    colorAccent:  root.colorAccent
    colorText:    root.colorText
    colorTextDim: root.colorTextDim
    onToggled: minhaVar = !minhaVar
}
```

## Adicionando uma nova aba

1. Crie `components/QsTabMinhaAba.qml` (mesma estrutura dos outros `QsTab*`)
2. Declare no `components/qmldir`:

   ```
   QsTabMinhaAba 1.0 QsTabMinhaAba.qml
   ```

3. Em `QuickSettingsContent.qml`, adicione a aba no array `tabs:`:

   ```qml
   { id: "minhaaba", label: "\uf000  Minha Aba" }
   ```

4. Adicione o bloco `Qs.QsTabMinhaAba` dentro do `Item` de páginas:

   ```qml
   Qs.QsTabMinhaAba {
       anchors.fill: parent
       visible:      root.activeTab === "minhaaba"
       colorText:    root.colorText
       colorTextDim: root.colorTextDim
   }
   ```

---

## Dependências do sistema

| Funcionalidade | Comando/Serviço                                       |
| -------------- | ----------------------------------------------------- |
| Volume         | PipeWire (`Quickshell.Services.Pipewire`)             |
| Wi-Fi          | NetworkManager (`Quickshell.Services.NetworkManager`) |
| System Tray    | `Quickshell.Services.SystemTray`                      |
| Brilho         | `brightnessctl` no PATH                               |
| Perfil térmico | `thermal-profile` no PATH + `/tmp/cpu_profile_state`  |
| Bluetooth      | `bluetoothctl` no PATH                                |
| Energia        | `~/.config/hypr/scripts/power.sh`                     |
