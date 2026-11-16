import '../dominio/acompanhamento_coleta.dart';

/// Minutos inteiros (mínimo 1) a partir de segundos.
int minutosDe(double segundos) {
  final m = (segundos / 60).ceil();
  return m < 1 ? 1 : m;
}

String _primeiroNome(String nome) => nome.trim().split(' ').first;

/// Status em linguagem simples (UC09). [etaSegundos] nulo = desconhecido.
String tituloStatus(AcompanhamentoColeta c, {double? etaSegundos}) {
  final nome = c.catador == null
      ? 'Seu catador'
      : _primeiroNome(c.catador!.nome);
  return switch (c.status) {
    StatusColeta.buscando => 'Buscando um catador perto de você',
    StatusColeta.aceita => '$nome aceitou sua coleta',
    StatusColeta.aCaminho =>
      etaSegundos == null
          ? 'Seu catador está a caminho'
          : 'Seu catador está a ${minutosDe(etaSegundos)} min',
    StatusColeta.noLocal => 'Seu catador chegou!',
    StatusColeta.coletada ||
    StatusColeta.entregue => 'Coleta concluída. Obrigado!',
    StatusColeta.cancelada => 'Coleta cancelada',
    StatusColeta.semCatador => 'Nenhum catador disponível agora',
  };
}

/// Orientação curta abaixo do título.
String? subtituloStatus(AcompanhamentoColeta c, {double? etaSegundos}) {
  return switch (c.status) {
    StatusColeta.buscando =>
      c.tentativasOferta > 0
          ? 'Tentativa ${c.tentativasOferta}. Já avisamos catadores da região.'
          : 'Estamos avisando os catadores da região.',
    StatusColeta.aceita =>
      etaSegundos == null
          ? 'Ele vai sair para buscar seus sacos.'
          : 'Chega em cerca de ${minutosDe(etaSegundos)} min.',
    StatusColeta.aCaminho => 'Fique de olho no celular.',
    StatusColeta.noLocal =>
      'Passe o código abaixo ao catador para liberar a coleta.',
    StatusColeta.semCatador => 'Tente novamente em alguns minutos.',
    StatusColeta.cancelada =>
      c.motivoCancelamento == null ||
              c.motivoCancelamento == 'sem_motivo_informado'
          ? null
          : 'Motivo: ${c.motivoCancelamento}',
    _ => null,
  };
}
