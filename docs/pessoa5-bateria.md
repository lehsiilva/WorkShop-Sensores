# Pessoa 5: Bateria e ciclo de vida

Responsável: Luis Felipe Rodrigues Almeida
Tempo na apresentação: 14:00 a 17:00 (3 min)

Código desta parte:

| Arquivo | O que faz |
|---|---|
| `notificacoes/lib/services/bateria_service.dart` | `BateriaService`, `ConfigLeitura`, `EstadoLeitura`, `RodadaLeitura` |
| `notificacoes/lib/widgets/painel_bateria.dart` | `PainelBateria` (interruptor, seletores, contador, pausa em segundo plano) |
| `notificacoes/lib/services/sensor_service.dart` | atalhos `iniciarLeituraContinua`, `pausarLeituras`, `retomarLeituras`, `pararTudo` |

---

## 1. Teoria

### Por que a leitura contínua gasta bateria

- **Leitura única** (`getCurrentPosition`, Pessoa 3): liga o GPS, espera um ponto, desliga.
- **Leitura contínua** (`getPositionStream`): o GPS fica **ligado enquanto houver alguém escutando o stream**.
- O chip de GPS escuta satélites o tempo todo. Cada posição nova também **acorda o processador** e faz o app redesenhar a tela.
- Por isso o Android e o iOS mostram o ícone de localização na barra de status e apontam o app como "alto consumo" nas configurações de bateria.

### O que aumenta ou diminui o custo

| Ajuste | Caro | Barato | Por quê |
|---|---|---|---|
| Precisão (`LocationAccuracy`) | `high` / `best` | `low` | `high` liga o chip de GPS; `low` usa a posição aproximada de rede e Wi-Fi, que já está calculada |
| `distanceFilter` | `0` m | `50` m | Com filtro, o app só é acordado quando o aparelho se move X metros |
| Intervalo (`intervalDuration`, só Android) | 1 s | 10 s | Menos leituras por minuto = menos vezes que o GPS e a CPU trabalham |
| Quando ler | sempre | só quando a tela precisa | Stream aberto em segundo plano é gasto sem ninguém olhar |

Regra prática: escolha a **menor precisão e a menor frequência que ainda atendem a função** do app.
Exemplos: navegação curva a curva precisa de `high` e filtro pequeno; mostrar "você está em Belo Horizonte" funciona com `low` e filtro de centenas de metros.

### Cancelar o stream: a parte mais importante

```dart
StreamSubscription<Position>? _assinatura;

_assinatura = Geolocator.getPositionStream(locationSettings: settings)
    .listen((posicao) { /* ... */ });

// Ao desligar, ao sair da tela (dispose) e ao ir para segundo plano:
await _assinatura?.cancel();
_assinatura = null;
```

- Enquanto a assinatura existir, o geolocator continua pedindo posições ao sistema.
- Se o widget for destruído sem `cancel()`, o GPS **continua ligado** e o callback ainda tenta usar um widget que não existe mais (vazamento de memória e erro de `setState` depois do `dispose`).
- Por isso o `PainelBateria.dispose()` cancela tudo.

### Pausar quando o app vai para segundo plano

O Flutter avisa as mudanças de estado do app pelo `WidgetsBindingObserver`:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.hidden:
    case AppLifecycleState.paused:
      _service.pausar();   // cancela o stream
    case AppLifecycleState.resumed:
      _service.retomar();  // abre de novo
    case AppLifecycleState.inactive:
    case AppLifecycleState.detached:
      break;
  }
}
```

Dois detalhes que valem pergunta do professor:

1. **Por que não pausar no `inactive`?** O `inactive` também acontece quando aparece o diálogo de permissão ou quando o usuário puxa a barra de notificações. O app continua visível; pausar ali faria a leitura piscar.
2. **Por que `cancel()` e não `subscription.pause()`?** O `pause()` só guarda os eventos num buffer: lá embaixo o GPS continua ligado. Para economizar de verdade é preciso cancelar e assinar de novo ao voltar.

O serviço guarda o estado `pausadaSegundoPlano` para saber que, ao voltar, deve reabrir o stream. Se o usuário tinha desligado o interruptor, continua desligado.

### Android vs. iOS (resumo)

- Android: `AndroidSettings` aceita `intervalDuration`. Leitura com o app em segundo plano exige `ACCESS_BACKGROUND_LOCATION` e serviço em primeiro plano com notificação; **não usamos**, de propósito.
- iOS: `AppleSettings(pauseLocationUpdatesAutomatically: true)` deixa o próprio sistema pausar quando o aparelho fica parado. O iOS ignora o intervalo; o `distanceFilter` vale.

---

## 2. Prática (o que o painel faz)

`PainelBateria` na tela inicial, logo abaixo do painel de GPS:

- **Interruptor "Leitura contínua do GPS"**: liga (`iniciar`) e desliga (`parar`). O subtítulo mostra o estado: *Desligada*, *Lendo* ou *Pausada: app em segundo plano*.
- **Atalhos**: *Alta precisão* (high, 0 m, 1 s) e *Economia* (low, 50 m, 10 s).
- **Seletores**: precisão (Alta/Baixa), `distanceFilter` (0/10/50 m) e intervalo (1/5/10 s).
  Trocar a configuração com a leitura ligada **cancela o stream e abre outro**, porque o stream do geolocator não muda de configuração depois de criado.
- **Custo estimado** (Alto/Médio/Baixo): regra qualitativa em `ConfigLeitura.custoEstimado`. Não é medição de mAh; serve para explicar o peso de cada escolha.
- **Contadores**: atualizações recebidas, tempo ligado (sem contar as pausas), atualizações por minuto e número de pausas.
- **Comparativo das rodadas**: cada vez que a leitura é desligada ou a configuração muda, a rodada vai para a lista com configuração, atualizações e taxa por minuto.

---

## 3. Roteiro da demo (emulador)

Preparação: no emulador, *Extended controls* (`...`) > *Location* > aba *Routes*, carregue uma rota e deixe a velocidade em 1x. Sem movimento, o `distanceFilter` não deixa chegar atualização nenhuma.

1. Tocar em **Alta precisão** e ligar **Leitura contínua do GPS**. Dar play na rota.
2. Deixar uns 20 s: o contador sobe quase a cada segundo. Mostrar *Custo estimado: Alto*.
3. Tocar em **Economia**. A rodada anterior vai para o comparativo e o contador recomeça.
4. Deixar uns 20 s: o contador sobe bem devagar. Comparar as duas linhas do comparativo (atualizações por minuto).
5. Apertar **Home** e voltar ao app: o estado mostra *Pausada* enquanto o app está fora e o contador de **Pausas** sobe. Explicar que o stream foi cancelado.
6. Desligar o interruptor: "nenhum stream aberto".

---

## 4. Slides (sugestão, 3 a 4 slides)

1. **Por que gasta bateria**: leitura única vs. contínua (GPS ligado + CPU acordando).
2. **Comparativo de configurações**: a tabela "Caro / Barato" acima, com os números das rodadas da demo.
3. **Boas práticas**: menor precisão que atende; `distanceFilter`; intervalo; ler só quando a tela precisa; pausar em segundo plano.
4. **Código do cancelamento**: o trecho do `cancel()` e do `didChangeAppLifecycleState`.

---

## 5. Perguntas prováveis

- **O que acontece se não cancelar o stream?** O GPS continua ligado, gastando bateria, e o callback chama `setState` num widget já destruído.
- **`distanceFilter` economiza mesmo com precisão alta?** Economiza CPU e redesenho (o app é acordado menos vezes). O chip de GPS ainda precisa estar ligado para saber se você andou, então o maior ganho vem de baixar a precisão.
- **Por que o contador não sobe no emulador?** Com `distanceFilter` maior que 0 e posição parada não há atualização. Use uma rota em *Extended controls* > *Location*.
- **Onde fica a lógica e onde fica a tela?** Lógica e assinatura no `BateriaService`; o `PainelBateria` só mostra e repassa os toques. O painel escuta o serviço com `ListenableBuilder` (o serviço é um `ChangeNotifier`).
- **E se o usuário desligar o GPS com a leitura ligada?** O stream manda um erro; o `onError` mostra a mensagem e chama `parar()`.
