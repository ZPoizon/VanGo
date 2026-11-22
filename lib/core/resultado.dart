class OperacaoResultado {
  const OperacaoResultado.ok([this.mensagem]) : sucesso = true;
  const OperacaoResultado.erro(this.mensagem) : sucesso = false;

  final bool sucesso;
  final String? mensagem;
}

enum LoginResultado {
  sucesso,
  credenciaisInvalidas,
  pendente,
  desativado,
  offline,
  semPerfil,
  dadosInconsistentes,
  permissoesNegadas,
  emailNaoVerificado,
  sessaoExpirada,
  configuracaoInvalida,
  dadosInvalidos,
  erroInterno;

  String get mensagem {
    switch (this) {
      case LoginResultado.sucesso:
        return 'Login realizado.';
      case LoginResultado.credenciaisInvalidas:
        return 'E-mail ou senha incorretos. Tente novamente.';
      case LoginResultado.pendente:
        return 'Sua solicitação ainda está pendente de aprovação.';
      case LoginResultado.desativado:
        return 'Esta conta está desativada. Procure o motorista do grupo.';
      case LoginResultado.offline:
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      case LoginResultado.semPerfil:
        return 'Conta sem perfil vinculado. Use o convite do motorista.';
      case LoginResultado.dadosInconsistentes:
        return 'Dados de ativação inconsistentes. Procure o motorista do grupo.';
      case LoginResultado.permissoesNegadas:
        return 'Seu perfil não tem permissão para ler estes dados. '
            'Procure o motorista do grupo.';
      case LoginResultado.emailNaoVerificado:
        return 'Confirme seu e-mail antes de entrar.';
      case LoginResultado.sessaoExpirada:
        return 'Sua sessão expirou. Entre novamente para continuar.';
      case LoginResultado.configuracaoInvalida:
        return 'O servidor não está pronto para esta consulta. '
            'Falta um índice no Firestore ou a operação está indisponível. '
            'Contate o administrador.';
      case LoginResultado.dadosInvalidos:
        return 'O servidor recusou os dados enviados. Confira as informações '
            'e tente novamente.';
      case LoginResultado.erroInterno:
        return 'Não foi possível concluir a operação. Tente novamente.';
    }
  }
}
