# Makefile for InstaDirectOnly
#
# InstaDirectOnly の Xcode プロジェクト向け共通タスク集。
# `make help` で利用可能なタスクを一覧表示できます。
#
# 変数はコマンドラインから上書き可能:
#   make build DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=latest'
#   make build CONFIG=Release

# ===== 変数 =====
PROJECT      ?= InstaDirectOnly.xcodeproj
SCHEME       ?= InstaDirectOnly
CONFIG       ?= Debug
DESTINATION  ?= platform=iOS Simulator,name=iPhone 15,OS=latest
DERIVED_DATA ?= build

XCODEBUILD   := xcodebuild \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-destination '$(DESTINATION)' \
	-derivedDataPath $(DERIVED_DATA)

# ===== ヘルプ (デフォルトターゲット) =====
.DEFAULT_GOAL := help

.PHONY: help
help: ## 利用可能なタスクを一覧表示
	@printf "Usage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ===== ビルド =====
.PHONY: build
build: ## デバッグビルドを実行 (iOS Simulator)
	$(XCODEBUILD) -configuration $(CONFIG) build

.PHONY: build-release
build-release: ## リリース構成でビルド
	$(XCODEBUILD) -configuration Release build

# ===== テスト =====
# NOTE: README の「テストターゲットを追加して実行する」節の手順で
#       InstaDirectOnlyTests を Xcode プロジェクトに登録した後で有効になります。
#       テストターゲット未登録の状態では xcodebuild が
#       "Scheme ... is not currently configured for the test action" を返します。
.PHONY: test
test: ## ユニットテストを実行 (要: テストターゲットが xcodeproj に登録済み)
	$(XCODEBUILD) test

# ===== クリーン =====
.PHONY: clean
clean: ## ビルド生成物を削除 (xcodebuild clean + DerivedData)
	-$(XCODEBUILD) -configuration $(CONFIG) clean
	rm -rf $(DERIVED_DATA) DerivedData

# ===== Lint / Format =====
.PHONY: lint
lint: ## SwiftLint を実行 (要: brew install swiftlint)
	@command -v swiftlint >/dev/null 2>&1 || { \
		echo "swiftlint が見つかりません。'brew install swiftlint' を実行するか、'make setup' でまとめて導入してください。"; \
		exit 1; \
	}
	swiftlint lint --quiet

.PHONY: lint-fix
lint-fix: ## SwiftLint の自動修正を実行
	@command -v swiftlint >/dev/null 2>&1 || { \
		echo "swiftlint が見つかりません。'brew install swiftlint' を実行するか、'make setup' でまとめて導入してください。"; \
		exit 1; \
	}
	swiftlint --fix --format

.PHONY: format
format: ## swift-format を実行 (要: brew install swift-format)
	@command -v swift-format >/dev/null 2>&1 || { \
		echo "swift-format が見つかりません。'brew install swift-format' を実行するか、'make setup' でまとめて導入してください。"; \
		exit 1; \
	}
	swift-format --in-place --recursive InstaDirectOnly InstaDirectOnlyTests

# ===== 便利コマンド =====
.PHONY: open
open: ## Xcode でプロジェクトを開く
	open $(PROJECT)

.PHONY: setup
setup: ## 開発ツール (SwiftLint / swift-format) を Homebrew で導入
	@command -v brew >/dev/null 2>&1 || { \
		echo "Homebrew が見つかりません。https://brew.sh/ を参照してインストールしてください。"; \
		exit 1; \
	}
	@brew list swiftlint    >/dev/null 2>&1 || brew install swiftlint
	@brew list swift-format >/dev/null 2>&1 || brew install swift-format

.PHONY: print-config
print-config: ## 現在の変数値を表示 (デバッグ用)
	@echo "PROJECT      = $(PROJECT)"
	@echo "SCHEME       = $(SCHEME)"
	@echo "CONFIG       = $(CONFIG)"
	@echo "DESTINATION  = $(DESTINATION)"
	@echo "DERIVED_DATA = $(DERIVED_DATA)"
