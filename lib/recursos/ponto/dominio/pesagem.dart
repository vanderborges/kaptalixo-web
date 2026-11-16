import 'falha_ponto.dart';

/// Preço vigente de um material no ponto (valor em centavos por kg).
class MaterialPreco {
  const MaterialPreco({
    required this.materialId,
    required this.nome,
    required this.precoKgCentavos,
  });

  final int materialId;
  final String nome;
  final int precoKgCentavos;
}

/// Peso informado para um material (centésimos de kg: 1,5 kg = 150).
class ItemPesagem {
  const ItemPesagem(this.materialId, this.pesoCentesimos);

  final int materialId;
  final int pesoCentesimos;
}

class LinhaPesagem {
  const LinhaPesagem({
    required this.materialId,
    required this.pesoCentesimos,
    required this.precoKgCentavos,
    required this.valorCentavos,
  });

  final int materialId;
  final int pesoCentesimos;
  final int precoKgCentavos;
  final int valorCentavos;
}

class ResumoPesagem {
  const ResumoPesagem(this.linhas);

  final List<LinhaPesagem> linhas;

  int get pesoTotalCentesimos => linhas.fold(0, (s, l) => s + l.pesoCentesimos);
  int get valorTotalCentavos => linhas.fold(0, (s, l) => s + l.valorCentavos);
}

/// Limites iguais aos de `registrar_entrega`.
const int maxItensPesagem = 20;
const int maxPesoCentesimos = 100000 * 100;

/// RN11: valor = soma por material de round(peso_kg x preço/kg, 2), com pesos
/// repetidos do mesmo material somados antes e peso arredondado a 2 casas.
/// Aritmética inteira (centésimos x centavos), meio arredonda para cima,
/// idêntica ao `round(numeric, 2)` do banco. Lança [FalhaPonto].
ResumoPesagem calcularPesagem(
  List<ItemPesagem> itens,
  Map<int, MaterialPreco> precos,
) {
  if (itens.isEmpty || itens.length > maxItensPesagem) {
    throw const FalhaPonto(MotivoFalhaPonto.parametroInvalido);
  }
  final somados = <int, int>{};
  for (final i in itens) {
    if (i.pesoCentesimos <= 0 || i.pesoCentesimos > maxPesoCentesimos) {
      throw const FalhaPonto(MotivoFalhaPonto.parametroInvalido);
    }
    somados[i.materialId] = (somados[i.materialId] ?? 0) + i.pesoCentesimos;
  }
  final ids = somados.keys.toList()..sort();
  final linhas = <LinhaPesagem>[];
  for (final id in ids) {
    final preco = precos[id];
    if (preco == null) {
      throw const FalhaPonto(MotivoFalhaPonto.materialSemPreco);
    }
    final peso = somados[id]!;
    // (peso/100 kg) x (preço/100 R$) = peso x preço / 100 centavos
    final valor = (peso * preco.precoKgCentavos + 50) ~/ 100;
    linhas.add(
      LinhaPesagem(
        materialId: id,
        pesoCentesimos: peso,
        precoKgCentavos: preco.precoKgCentavos,
        valorCentavos: valor,
      ),
    );
  }
  return ResumoPesagem(linhas);
}

/// Converte texto digitado ("1,5", "2.25") em centésimos de kg, arredondando
/// a 2 casas (meio para cima). Nulo se vazio ou inválido.
int? parsePesoKg(String texto) {
  final t = texto.trim().replaceAll(',', '.');
  final m = RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(t);
  if (m == null) return null;
  final inteiro = int.tryParse(m.group(1)!);
  if (inteiro == null) return null;
  final frac = (m.group(2) ?? '').padRight(3, '0');
  var c = inteiro * 100 + int.parse(frac.substring(0, 2));
  if (int.parse(frac[2]) >= 5) c++;
  return c;
}

/// "R$ 1.234,56".
String formatarReais(int centavos) {
  final neg = centavos < 0;
  final abs = centavos.abs();
  final reais = (abs ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}R\$ $buf,$cents';
}

/// "12,50 kg".
String formatarKg(int centesimos) {
  final i = centesimos ~/ 100;
  final f = (centesimos % 100).toString().padLeft(2, '0');
  return '$i,$f kg';
}
