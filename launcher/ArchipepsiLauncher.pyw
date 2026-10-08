"""Entry point for the packaged executable (and for double-clicking on a
machine that has Python): `pythonw ArchipepsiLauncher.pyw [zip ...]`."""
import sys

from archipepsi_launcher.gui import main

sys.exit(main())
