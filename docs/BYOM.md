# Bring your own model

Edge Lab does not download models in v1. Add a `.litertlm` file using any of these paths:

## 1. AI Edge Gallery → Files (fastest on iPhone)

1. Install [Google AI Edge Gallery](https://apps.apple.com/us/app/google-ai-edge-gallery/id6749645337).
2. Download a model inside the app.
3. Open **Files** → **On My iPhone** → **Edge Gallery**.
4. Copy the `.litertlm` file to **Edge Lab** (same Files location) or import via **+** in Edge Lab.

## 2. Import into Edge Lab

Tap **+** in Edge Lab and select a `.litertlm` from Files or iCloud. The app stores a security-scoped bookmark for re-access.

## 3. Hugging Face (desktop or Safari)

1. Open [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm).
2. Accept the Gemma license if prompted.
3. Download a `.litertlm` artifact (~2.6 GB).
4. AirDrop or cable-copy to the iPhone, then import in Edge Lab.

## Requirements

- iOS 17+
- Sufficient free storage and RAM for the model (see Hugging Face model card)
- `increased-memory-limit` entitlement (included in the project)