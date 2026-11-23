String? validarObrigatorio(String? valor, String campo) {
  if (valor == null || valor.trim().isEmpty) return 'Informe $campo.';
  return null;
}

String? validarNome(String? valor) {
  final obrigatorio = validarObrigatorio(valor, 'o nome');
  if (obrigatorio != null) return obrigatorio;
  if (valor!.trim().length < 3) return 'O nome deve ter ao menos 3 letras.';
  return null;
}

String? validarEmail(String? valor) {
  final obrigatorio = validarObrigatorio(valor, 'o e-mail');
  if (obrigatorio != null) return obrigatorio;
  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!regex.hasMatch(valor!.trim())) return 'Informe um e-mail válido.';
  return null;
}

String? validarTelefone(String? valor) {
  final obrigatorio = validarObrigatorio(valor, 'o telefone');
  if (obrigatorio != null) return obrigatorio;
  final digitos = valor!.replaceAll(RegExp(r'\D'), '');
  if (digitos.length < 10) return 'Informe DDD + número.';
  return null;
}

String? validarSenha(String? valor) {
  final obrigatorio = validarObrigatorio(valor, 'a senha');
  if (obrigatorio != null) return obrigatorio;
  if (valor!.length < 6) return 'A senha deve ter ao menos 6 caracteres.';
  return null;
}

String? validarEndereco(String? valor) =>
    validarObrigatorio(valor, 'o endereço de embarque');

String? validarConfirmacaoSenha(String? valor, String senha) {
  final obrigatorio = validarObrigatorio(valor, 'a confirmação da senha');
  if (obrigatorio != null) return obrigatorio;
  if (valor != senha) return 'As senhas não coincidem.';
  return null;
}

/// Aplica a máscara `00000-000` enquanto o CEP é digitado.
String aplicarMascaraCep(String valor) {
  final digitos = valor.replaceAll(RegExp(r'\D'), '');
  final limitados = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
  if (limitados.length <= 5) return limitados;
  return '${limitados.substring(0, 5)}-${limitados.substring(5)}';
}

String? validarCep(String? valor) {
  final obrigatorio = validarObrigatorio(valor, 'o CEP');
  if (obrigatorio != null) return obrigatorio;
  final digitos = valor!.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 8) return 'Informe o CEP com 8 dígitos.';
  return null;
}
