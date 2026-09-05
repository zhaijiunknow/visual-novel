class_name CollectionData
extends Resource

@export var voice_collections: Array[VoiceCollection]
# 已解锁(在剧情里播放过)的 CG 名，键与 SetCG 传入的 cg_name 一致
@export var unlocked_cgs: Array[String] = []
