import '../dominio/acompanhamento_coleta.dart';

String _primeiroNome(String nome) => nome.trim().split(' ').first;

/// Status em linguagem simples (UC09). A chegada estimada fica em
/// `TextoChegada` (ETA da rota planejada, T6.5).
String tituloStatus(AcompanhamentoColeta c) {
  final nome = c.catador == null
      ? 'Seu catador'
      : _primeiroNome(c.catador!.nome);
  return switch (c.status) {
    StatusColeta.buscando => 'Buscando um catador perto de você',
    StatusColeta.aceita => '$nome aceitou sua coleta',
    StatusColeta.aCaminho => 'Seu catador está a caminho',
    StatusColeta.noLocal => 'Seu catador chegou!',
    StatusColeta.coletada ||
    StatusColeta.entregue => 'Coleta concluída. Obrigado!',
    StatusColeta.cancelada => 'Coleta cancelada',
    StatusColeta.semCatador => 'Nenhum catador disponível agora',
  };
}

/// Orientação curta abaixo do título.
String? subtituloStatus(AcompanhamentoColeta c) {
  return switch (c.status) {
    StatusColeta.buscando =>
      c.tentativasOferta > 0
          ? 'Tentativa ${c.tentativasOferta}. Já avisamos catadores da região.'
          : 'Estamos avisando os catadores da região.',
    StatusColeta.aceita => 'Ele vai sair para buscar seus sacos.',
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
