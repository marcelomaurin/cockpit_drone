<?php
declare(strict_types=1);

namespace MundoDrone;

/** Cálculos geográficos do filtro de 2 km. */
final class Geo
{
    public const RAIO_TERRA_M = 6371000.0;
    public const METROS_POR_GRAU_LAT = 111320.0;

    /** Distância em metros pela fórmula de haversine (só a posição horizontal). */
    public static function distanciaM(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $f1 = deg2rad($lat1);
        $f2 = deg2rad($lat2);
        $df = $f2 - $f1;
        $dl = deg2rad($lon2 - $lon1);
        $a = sin($df / 2) ** 2 + cos($f1) * cos($f2) * sin($dl / 2) ** 2;
        return 2 * self::RAIO_TERRA_M * asin(min(1.0, sqrt($a)));
    }

    /**
     * Retângulo que contém o círculo de raio $raioM (para usar o índice do banco).
     * @return array{latMin: float, latMax: float, lonMin: float, lonMax: float}
     */
    public static function retangulo(float $lat, float $lon, float $raioM): array
    {
        $dLat = $raioM / self::METROS_POR_GRAU_LAT;
        $cos = max(0.01, cos(deg2rad($lat)));
        $dLon = $dLat / $cos;
        return [
            'latMin' => $lat - $dLat,
            'latMax' => $lat + $dLat,
            'lonMin' => $lon - $dLon,
            'lonMax' => $lon + $dLon,
        ];
    }
}
