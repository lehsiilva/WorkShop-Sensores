# Sensores e Geolocalização em Flutter

Projeto do Workshop Técnico (PUC Minas, Laboratório de Desenvolvimento para Dispositivos Móveis).
O app demonstra:

- leitura de **GPS** com `geolocator` (posição atual, precisão, distância entre dois pontos);
- leitura dos **sensores de movimento** com `sensors_plus` (acelerômetro, giroscópio e magnetômetro, com nível de bolha, bússola e detector de "chacoalhar");
- o **fluxo de permissões** de localização: concedida, negada, negada para sempre e serviço de localização desligado;
- o **custo de bateria** da leitura contínua e a importância de cancelar os streams.

## Estado atual

> Este README descreve o estado da branch `main` em 27/11/2026.

**O que já está escrito**

- GPS, leitura única (Pessoa 3): `GpsService` + `PainelGps`, que já aparece na tela inicial.
- Sensores de movimento (Pessoa 4): `MovimentoService` + `PainelMovimento`.
- Permissões (Pessoa 2): `LocationPermissionService` + `PermissionPanel`.
- Ponto central (Pessoa 1): `SensorService`, que delega para os três serviços acima.

**O que NÃO compila hoje** (`flutter analyze`)

| Arquivo | Problema | Dono |
|---|---|---|
| `lib/main.dart` (linhas 2–8) | Marcadores de merge não resolvidos (`<<<<<<<`, `=======`, `>>>>>>>`) | Pessoa 2 (Thayná) |
| `lib/main.dart` (linha 45) | Usa `DetailScreen`, mas `screens/detail_screen.dart` foi apagado | Pessoa 4 (Letícia) / Pessoa 6 |
| `lib/services/location_permition_service.dart` (linha 10) | Falta o `}` que fecha o `enum LocationAccess` | Pessoa 2 (Thayná) |
| `lib/widgets/painel_permissao.dart` (linha 2) | O import `../../services/location_permission_service.dart` sobe uma pasta a mais e escreve o nome do arquivo diferente do real (`permition`) | Pessoa 2 (Thayná) |
| `test/widget_test.dart` (linha 16) | Usa `MyApp`, que vem do template do Flutter e não existe mais | Pessoa 6 |

**O que ainda falta**

- `PainelMovimento` e `PermissionPanel` não estão na tela inicial (`HomeScreen`).
- Faltam as permissões de localização no Android e no iOS (veja abaixo).
- Bateria e ciclo de vida (Pessoa 5): ainda não há leitura contínua do GPS (`getPositionStream` com `distanceFilter`) nem pausa dos sensores quando o app vai para segundo plano.

## Como executar

Pré-requisitos: Flutter SDK instalado (`flutter doctor` sem erros) e um emulador Android ou um aparelho físico.
Versão testada: **Flutter 3.50.0 (stable), Dart 3.14.0**.

```bash
git clone https://github.com/lehsiilva/WorkShop-Sensores.git
cd WorkShop-Sensores/notificacoes
flutter pub get
flutter run
```

Dicas para o emulador Android:

- **GPS:** em *Extended controls* (botão `...`) > *Location*, defina uma posição e clique em *Set location*.
- **Sensores:** em *Extended controls* > *Virtual sensors*, mexa o aparelho virtual para gerar valores.

Num aparelho físico os sensores funcionam direto.

## Estrutura do projeto

```
notificacoes/lib/
  main.dart                                  # inicia o app e define as rotas
  screens/
    home_screen.dart                         # tela inicial com os painéis
  services/                                  # lógica (sem interface)
    sensor_service.dart                      # Pessoa 1: ponto central, só delega
    location_permition_service.dart          # Pessoa 2: permissões de localização
    gps_service.dart                         # Pessoa 3: GPS
    movimento_service.dart                   # Pessoa 4: acelerômetro, giroscópio, magnetômetro
    notification_service.dart                # resto do workshop de notificações
  widgets/                                   # um painel (Card) por parte
    painel_permissao.dart                    # Pessoa 2
    painel_gps.dart                          # Pessoa 3
    painel_movimento.dart                    # Pessoa 4
```

Regra da arquitetura: os **services** fazem o trabalho e os **widgets** só mostram o resultado.
O `SensorService.instance` reúne os services num único lugar, sem duplicar a lógica de ninguém.

## Quem faz o quê

| Pessoa | Parte | Responsável | Classes e métodos no código |
|---|---|---|---|
| 1 | Fundamentos, arquitetura, README | Daniel Pimenta | `SensorService.instance`: `verificarPermissao`, `pedirPermissao`, `garantirPermissao`, `abrirConfiguracoesApp`, `abrirConfiguracoesLocalizacao`, `obterLocalizacaoAtual`, `calcularDistanciaMetros`, `acelerometro`, `giroscopio`, `magnetometro` |
| 2 | Permissões | Thayná Andrade | `LocationPermissionService`: `check`, `request`, `ensureGranted`, `openAppSettings`, `openLocationSettings`; `enum LocationAccess`; `PermissionPanel` |
| 3 | Geolocalização | Lucas Reis | `GpsService`: `obterLocalizacaoAtual`, `calcularDistanciaMetros`, `formatarDistancia`; `GpsException`; `PainelGps` |
| 4 | Sensores de movimento | Letícia Lopes | `MovimentoService`: `acelerometro`, `giroscopio`, `magnetometro`, `forcaG`, `direcaoGraus`, `pontoCardeal`; `DetectorChacoalhar.processar`; `PainelMovimento` |
| 5 | Bateria e ciclo de vida | A definir | (nada implementado ainda; há um bloco `TODO Pessoa 5` em `sensor_service.dart`) |
| 6 | Integração, UI e demo | A definir | `HomeScreen`, `main.dart` |

## Requisitos do professor

| Requisito | Quem cobre | Situação |
|---|---|---|
| Ler pelo menos 2 sensores | Pessoa 3 (GPS) e Pessoa 4 (acelerômetro, giroscópio, magnetômetro) | Código pronto; o `PainelMovimento` ainda não está na tela |
| Fluxo de permissão, incluindo recusa | Pessoa 2 | Código trata negada, negada para sempre e GPS desligado; ainda não compila e não está na tela |
| Funcionar no emulador ou no aparelho | Pessoa 6 (integração) | Bloqueado pelos erros de compilação e pelas permissões que faltam |
| Custo de bateria da leitura contínua | Pessoa 5 | Pendente (hoje só o `PainelMovimento` cancela os streams ao desligar) |
| README com instruções de execução | Pessoa 1 | Este arquivo |

## Permissões necessárias

O Android e o iOS exigem duas coisas:

1. **Declarar** a permissão no manifesto (Android) ou no `Info.plist` (iOS).
2. **Pedir** a permissão em tempo de execução, com o usuário podendo negar. Isso é feito pelo `LocationPermissionService`.

### Android: `notificacoes/android/app/src/main/AndroidManifest.xml`

> ⚠️ **AINDA NÃO ESTÃO NO MANIFESTO (responsável: Pessoa 2).** Sem elas o pedido de localização falha.

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

Os sensores de movimento (acelerômetro, giroscópio, magnetômetro) **não** precisam de permissão.

O manifesto hoje tem apenas permissões do workshop de notificações: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` e `RECEIVE_BOOT_COMPLETED`.

### iOS: `notificacoes/ios/Runner/Info.plist`

> ⚠️ **AINDA NÃO ESTÁ NO INFO.PLIST (responsável: Pessoa 2).** Sem ela o iOS encerra o app ao pedir a localização.

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>O app usa sua localização para mostrar a posição atual no workshop.</string>
```

## Roteiro da demonstração

Os botões abaixo usam os textos reais do código.
Os passos marcados com (*) dependem de o painel ser colocado na tela inicial pela Pessoa 6.

1. **Permissões (*)**, no `PermissionPanel`:
   1. Mostrar o estado "Verificando..." e depois tocar em **Pedir permissão**.
   2. Negar o pedido: aparece "Permissão negada".
   3. Negar de novo: aparece "Negada definitivamente", com o botão **Abrir configurações do app**.
   4. Desligar a localização do aparelho: aparece **Ativar localização**.
   5. Tocar em **Verificar de novo**.
2. **GPS**, no `PainelGps` (já está na tela):
   1. Tocar em **Obter localização atual**: mostra latitude, longitude, precisão e hora.
   2. Tocar em **Marcar ponto de referência (distância)**.
   3. Mudar a posição no emulador.
   4. Tocar em **Obter localização atual** de novo: aparece a distância do ponto salvo.
3. **Sensores de movimento (*)**, no `PainelMovimento`:
   1. Ligar **Ler sensores em tempo real**.
   2. Inclinar o aparelho: o nível de bolha se move.
   3. Girar o aparelho: a bússola acompanha.
   4. Chacoalhar o aparelho: aparece "Chacoalhou!".
4. **Bateria**: desligar **Ler sensores em tempo real** e explicar que isso cancela os streams. A parte da Pessoa 5 ainda está pendente.

## Pendências

- **Restos do workshop de notificações** (mantidos de propósito por enquanto):
  - nome do projeto/pacote `notificacoes`;
  - título do app "Notificações Locais" (`main.dart` e `HomeScreen`);
  - as seções de notificação na `HomeScreen` e o `notification_service.dart`;
  - a rota `/detalhe`;
  - as permissões de alarme e boot no manifesto (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED` e os receivers).
- **Sugestão para a Pessoa 2 (Thayná) decidir:** renomear `location_permition_service.dart` para `location_permission_service.dart`, que é o nome que o `painel_permissao.dart` já espera. Se renomear, ajustar também o import em `sensor_service.dart`.
- Corrigir os erros de compilação listados em [Estado atual](#estado-atual).
- Colocar `PermissionPanel` e `PainelMovimento` na `HomeScreen` (Pessoa 6).
- Implementar a parte da Pessoa 5 (bloco `TODO Pessoa 5` em `sensor_service.dart`).

## Referências

- geolocator: https://pub.dev/packages/geolocator
- sensors_plus: https://pub.dev/packages/sensors_plus
- permission_handler: https://pub.dev/packages/permission_handler
- Android, visão geral dos sensores: https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview
- Android, localização: https://developer.android.com/develop/sensors-and-location/location
