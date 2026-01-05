#!/usr/bin/env python3
"""
Setup ML Training Environment for Lulla Voice Commands

This script sets up the Python environment and validates dependencies.
"""

import sys
import subprocess
from pathlib import Path


def check_python_version():
    """Ensure Python 3.9+"""
    if sys.version_info < (3, 9):
        print(f"❌ Python 3.9+ required, found {sys.version_info.major}.{sys.version_info.minor}")
        sys.exit(1)
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")


def install_dependencies():
    """Install requirements.txt"""
    requirements_path = Path(__file__).parent.parent / "requirements.txt"

    if not requirements_path.exists():
        print(f"❌ requirements.txt not found at {requirements_path}")
        sys.exit(1)

    print(f"📦 Installing dependencies from {requirements_path}...")
    subprocess.check_call([
        sys.executable, "-m", "pip", "install", "-r", str(requirements_path)
    ])
    print("✅ Dependencies installed")


def verify_imports():
    """Verify critical imports work"""
    imports = [
        ("torch", "PyTorch"),
        ("transformers", "Hugging Face Transformers"),
        ("coremltools", "CoreML Tools"),
        ("sklearn", "scikit-learn"),
        ("pytest", "pytest"),
    ]

    for module, name in imports:
        try:
            __import__(module)
            print(f"✅ {name}")
        except ImportError:
            print(f"❌ {name} not installed")
            sys.exit(1)


def check_torch_metal():
    """Check if PyTorch can use Apple Metal (for Mac M1/M2)"""
    try:
        import torch
        if torch.backends.mps.is_available():
            print("✅ Apple Metal (GPU acceleration) available")
        else:
            print("⚠️  Apple Metal not available (CPU only)")
    except Exception as e:
        print(f"⚠️  Could not check Metal support: {e}")


def main():
    print("=" * 60)
    print("Lulla Voice Command ML Training Environment Setup")
    print("=" * 60)

    check_python_version()
    install_dependencies()
    verify_imports()
    check_torch_metal()

    print("\n" + "=" * 60)
    print("✅ Environment setup complete!")
    print("=" * 60)
    print("\nNext steps:")
    print("  1. Create training dataset: python scripts/paraphrase_generator.py")
    print("  2. Run evaluation: python scripts/evaluate_model.py")
    print("  3. Train model: python scripts/train_model.py")


if __name__ == "__main__":
    main()
