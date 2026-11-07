<?php
declare(strict_types=1);

namespace MundoDrone;

/** Validação dos campos recebidos. Todo valor fora do esperado vira HTTP 400. */
final class Validacao
{
    public static function apelido(mixed $v): string
    {
        if (!is_string($v)) {
            throw new ErroApi(400, 'apelido', 'Informe um apelido.');
        }
        $v = trim($v);
        if (!preg_match('/^[\p{L}\p{N}_-]{3,32}$/u', $v)) {
            throw new ErroApi(400, 'apelido', 'Apelido: 3 a 32 caracteres, letras, números, "-" e "_".');
        }
        return $v;
    }

    public static function modelo(mixed $v): string
    {
        if (!is_string($v) || !preg_match('/^[a-z0-9_-]{1,24}$/', $v)) {
            throw new ErroApi(400, 'modelo', 'Modelo inválido.');
        }
        return $v;
    }

    /** @return array{0: float, 1: float, 2: float} */
    public static function posicao(mixed $p): array
    {
        if (!is_array($p)) {
            throw new ErroApi(400, 'posicao', 'Informe posicao {lat, lon, alt}.');
        }
        $lat = self::numero($p['lat'] ?? null, -85, 85, 'lat');
        $lon = self::numero($p['lon'] ?? null, -180, 180, 'lon');
        $alt = self::numero($p['alt'] ?? 0, -100, 10000, 'alt');
        return [$lat, $lon, $alt];
    }

    public static function numero(mixed $v, float $min, float $max, string $campo): float
    {
        if (!is_int($v) && !is_float($v)) {
            throw new ErroApi(400, $campo, "Campo \"$campo\" precisa ser número.");
        }
        $f = (float) $v;
        if (!is_finite($f) || $f < $min || $f > $max) {
            throw new ErroApi(400, $campo, "Campo \"$campo\" fora do limite.");
        }
        return $f;
    }

    public static function inteiro(mixed $v, int $min, int $max, string $campo): int
    {
        if (is_float($v) && floor($v) === $v) {
            $v = (int) $v;
        }
        if (!is_int($v) || $v < $min || $v > $max) {
            throw new ErroApi(400, $campo, "Campo \"$campo\" precisa ser inteiro entre $min e $max.");
        }
        return $v;
    }

    /** @param list<string> $opcoes */
    public static function opcao(mixed $v, array $opcoes, string $campo): string
    {
        if (!is_string($v) || !in_array($v, $opcoes, true)) {
            throw new ErroApi(400, $campo, "Campo \"$campo\" deve ser: " . implode(', ', $opcoes) . '.');
        }
        return $v;
    }

    public static function texto(mixed $v, int $min, int $max, string $campo): string
    {
        if (!is_string($v)) {
            throw new ErroApi(400, $campo, "Campo \"$campo\" precisa ser texto.");
        }
        $v = trim(preg_replace('/[\x00-\x1F\x7F]/u', ' ', $v) ?? '');
        $n = mb_strlen($v, 'UTF-8');
        if ($n < $min || $n > $max) {
            throw new ErroApi(400, $campo, "Campo \"$campo\": $min a $max caracteres.");
        }
        return $v;
    }
}
