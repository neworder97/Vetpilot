# Real radiograph CI fixture attribution

The CI workflow downloads `dog_thorax_vd_test.jpg` at build time from Wikimedia Commons:

- File: `Radiographie thoracique ventro-dorsale.jpg`
- Description: thoracic radiograph of a large dog, ventrodorsal projection
- Author: Ophélie TISSIER
- Source: https://commons.wikimedia.org/wiki/File:Radiographie_thoracique_ventro-dorsale.jpg
- License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
- Original SHA-1 published by Wikimedia Commons: `4ceffb1d1ce052cdaeb52d08d8142fc1b62975ab`

The fixture is used only to exercise the real production radiograph-analysis path in automated iOS tests. The image is not bundled into the shipping VetPilot application target.
