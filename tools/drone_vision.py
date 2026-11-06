#!/usr/bin/env python3
"""Cockpit Drone: deteccao e rastreamento local, desacoplado do voo.

Padrao: YOLO (objetos/pessoas) + BoT-SORT (IDs) + MediaPipe Pose (33 pontos).
Entrada: vision_frame.bmp; saidas: vision_result.json, vision_result.txt,
vision_annotated.jpg. Nao controla o drone e nao envia quadros a servicos externos.
Requer: pip install opencv-python ultralytics mediapipe
Uso: python tools/drone_vision.py [diretorio-config] [--model caminho/modelo.pt]
"""
import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import cv2


def default_dir():
    if os.name == "nt":
        return Path(os.environ.get("APPDATA", str(Path.home()))) / "cockpit_drone"
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "cockpit_drone"


def atomic_text(path, content):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", nargs="?", type=Path, default=default_dir())
    parser.add_argument("--model", default="yolo11n.pt", help="Pesos YOLO locais; pode baixar na primeira execucao")
    parser.add_argument("--confidence", type=float, default=0.4)
    parser.add_argument("--interval", type=float, default=0.2)
    args = parser.parse_args()
    if not 0 < args.confidence <= 1:
        parser.error("--confidence deve estar entre 0 e 1")

    from ultralytics import YOLO
    import mediapipe as mp

    directory = args.directory.expanduser()
    directory.mkdir(parents=True, exist_ok=True)
    source = directory / "vision_frame.bmp"
    result_path = directory / "vision_result.json"
    text_path = directory / "vision_result.txt"
    annotated_path = directory / "vision_annotated.jpg"

    detector = YOLO(args.model)
    pose_api = getattr(getattr(mp, "solutions", None), "pose", None)
    if pose_api is None:
        raise RuntimeError("Instale uma versao MediaPipe com solutions.pose")

    last_mtime = None
    with pose_api.Pose(static_image_mode=False, model_complexity=1,
                       min_detection_confidence=0.6,
                       min_tracking_confidence=0.5) as pose:
        while True:
            try:
                stamp = source.stat().st_mtime_ns
                if stamp == last_mtime:
                    time.sleep(args.interval)
                    continue
                # A camera grava o BMP diretamente; em caso de leitura parcial,
                # repetir na proxima iteracao em vez de descartar o quadro.
                img = cv2.imread(str(source))
                if img is None:
                    time.sleep(args.interval)
                    continue
                last_mtime = stamp
                h, w = img.shape[:2]
                # BoT-SORT e apropriado para cameras moveis; persistencia
                # so vale enquanto os quadros pertencem a mesma fonte.
                result = detector.track(img, persist=True, tracker="botsort.yaml",
                                        conf=args.confidence, verbose=False)[0]
                objects = []
                boxes = result.boxes
                if boxes is not None:
                    for box in boxes:
                        cls = int(box.cls[0].item())
                        coords = [round(float(v), 2) for v in box.xyxy[0].tolist()]
                        track_id = int(box.id[0].item()) if box.id is not None else None
                        objects.append({
                            "class_id": cls,
                            "label": str(result.names[cls]),
                            "confidence": round(float(box.conf[0].item()), 4),
                            "track_id": track_id,
                            "bbox_xyxy": coords,
                        })
                annotated = result.plot()
                # MediaPipe Pose e um estimador de uma pose predominante;
                # nao representa poses de todas as pessoas detectadas.
                pose_result = pose.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
                landmarks = []
                if pose_result.pose_landmarks is not None:
                    for index, landmark in enumerate(pose_result.pose_landmarks.landmark):
                        landmarks.append({
                            "id": index,
                            "x": round(float(landmark.x), 5),
                            "y": round(float(landmark.y), 5),
                            "z": round(float(landmark.z), 5),
                            "visibility": round(float(landmark.visibility), 5),
                        })
                        if landmark.visibility > 0.5:
                            cv2.circle(annotated,
                                       (int(landmark.x * w), int(landmark.y * h)),
                                       3, (0, 255, 255), -1)
                data = {
                    "schema_version": 1,
                    "timestamp_utc": datetime.now(timezone.utc).isoformat(),
                    "frame_width": w, "frame_height": h,
                    "objects": objects,
                    "pose_landmarks": landmarks,
                    "pose_scope": "single_primary_person",
                    "autonomous_flight_commands": False,
                }
                atomic_text(result_path, json.dumps(data, ensure_ascii=False))
                people = sum(o["label"] == "person" for o in objects)
                atomic_text(text_path, f"Visao IA: {people} pessoa(s), {len(objects)} objeto(s), pose: {'sim' if landmarks else 'nao'}\n")
                # Escrita temporaria para evitar leitura de imagem incompleta.
                temp_image = directory / "vision_annotated.tmp.jpg"
                if cv2.imwrite(str(temp_image), annotated):
                    temp_image.replace(annotated_path)
            except FileNotFoundError:
                pass
            except Exception as exc:
                atomic_text(text_path, "Visao IA: erro no analisador; consulte o console\n")
                print(f"Erro de visao: {exc}", flush=True)
            time.sleep(args.interval)


if __name__ == "__main__":
    main()
