<?php
declare(strict_types=1);

namespace MundoDrone;

/** Erro que vira resposta JSON {"ok":false,"erro":...,"mensagem":...}. */
final class ErroApi extends \RuntimeException
{
    public function __construct(
        public readonly int $status,
        public readonly string $codigo,
        string $mensagem
    ) {
        parent::__construct($mensagem);
    }
}
