#!/usr/bin/env python3
"""Analisador local opcional de quadros do Cockpit Drone.

Instalacao: pip install opencv-python mediapipe
Execucao: python tools/drone_vision.py
Nao envia imagens para a nuvem nem controla o voo.
"""
import os
import sys
import time
from pathlib import Path

import cv2
import mediapipe as mp


def config_dir():
    if os.name == "nt":
        return Path(os.environ.get("APPDATA", str(Path.home()))) / "cockpit_drone"
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "cockpit_drone"


def main():
    directory = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else config_dir()
    directory.mkdir(parents=True, exist_ok=True)
    frame = directory / "vision_frame.bmp"
    output = directory / "vision_result.txt"
    last_mtime = None
    pose_api = getattr(getattr(mp, "solutions", None), "pose", None)
    if pose_api is None:
        raise RuntimeError("MediaPipe solutions.pose indisponivel nesta versao. Instale uma versao compativel.")
    with pose_api.Pose(static_image_mode=True, model_complexity=1,
                       min_detection_confidence=0.6) as detector:
        while True:
            try:
                stat = frame.stat()
                if stat.st_mtime_ns != last_mtime:
                    last_mtime = stat.st_mtime_ns
                    img = cv2.imread(str(frame))
                    if img is not None:
                        result = detector.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
                        has_pose = result.pose_landmarks is not None
                        text = "Visao IA: pose humana detectada" if has_pose else "Visao IA: nenhuma pose detectada"
                        temp = output.with_suffix(".tmp")
                        temp.write_text(text + "\n", encoding="utf-8")
                        temp.replace(output)
            except FileNotFoundError:
                pass
            except Exception as exc:
                print(f"Erro de analise: {exc}", flush=True)
            time.sleep(0.2)


if __name__ == "__main__":
    main()
