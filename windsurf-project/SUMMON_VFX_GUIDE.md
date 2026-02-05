# Summon Animation VFX Guide

## Overview
The new summon animation system displays tower models in a ViewportFrame with custom particle effects. This guide explains how to add VFX to your tower models.

## How It Works

When a tower is summoned, the system:
1. **Hides all GUI** except the ResultFrame
2. **Adds blur effect** to the background (24 size blur)
3. **Creates ViewportFrame** with the tower model
4. **Looks for VFX** in the model's `SummonVFX` attachment
5. **Displays the tower** with particle effects playing

## Adding VFX to Tower Models

### Step 1: Create Attachment
In your tower model's **PrimaryPart** (usually HumanoidRootPart):
1. Add an **Attachment** instance
2. Name it exactly: `SummonVFX`

### Step 2: Add Particle Effects
Inside the `SummonVFX` attachment, add any of these VFX:
- **ParticleEmitter** - For particle effects (recommended)
- **Beam** - For beam effects
- **Trail** - For trail effects

### Step 3: Configure Your VFX
The system will automatically:
- Enable all ParticleEmitters found in the attachment
- Play them during the summon animation
- Clean them up when the animation closes

## Example Structure

```
Silver (Model)
├── HumanoidRootPart (PrimaryPart)
│   ├── SummonVFX (Attachment)
│   │   ├── Sparkles (ParticleEmitter)
│   │   │   ├── Enabled = false (will be enabled during summon)
│   │   │   ├── Texture = "rbxassetid://..."
│   │   │   ├── Color = ColorSequence
│   │   │   └── Rate = 50
│   │   └── Glow (ParticleEmitter)
│   │       └── ... (your settings)
│   └── ... (other parts)
└── ... (other parts)
```

## VFX Tips

### Particle Emitter Settings
- **Rate**: 30-100 for good visibility
- **Lifetime**: 1-3 seconds
- **Speed**: 5-15 for gentle floating effect
- **Size**: Start at 0.5-1, end at 0
- **Transparency**: Start at 0, end at 1 for fade out
- **Enabled**: Set to `false` in Studio (system enables it automatically)

### Rarity-Based VFX Ideas
- **Common**: Simple white sparkles
- **Rare**: Blue/green particles with slight glow
- **Epic**: Purple/pink particles with rotation
- **Legendary**: Gold particles with multiple emitters, beams, or trails

### Performance
- Keep particle count reasonable (Rate < 100)
- Use shorter lifetimes (1-2 seconds)
- Avoid too many emitters per tower (2-3 max)

## Camera Positioning

The ViewportFrame camera is positioned at:
- **Position**: `model.Position + Vector3.new(0, 2, 5)`
- **LookAt**: `model.Position + Vector3.new(0, 1.5, 0)`

This gives a nice angled view of the tower. Adjust your VFX positioning accordingly.

## Testing Your VFX

1. Place the tower model in `ReplicatedStorage.Towers`
2. Add it to `TowerData.lua` with proper ID and Model name
3. Summon it in-game
4. The VFX should play automatically during the summon animation

## Advanced: Custom VFX Per Tower

You can create unique summon effects for each tower:
- Different particle textures
- Different colors matching tower theme
- Multiple particle emitters for complex effects
- Beams or trails for special towers

## GUI Requirements

Make sure your `SummonUI.ResultFrame` contains:
- **ViewportFrame** - Where the tower model displays
- **TowerName** - TextLabel for tower name
- **Rarity** - TextLabel for rarity
- **Description** - TextLabel for description

## Notes

- VFX automatically stops when the summon animation closes
- The blur effect fades in/out smoothly (0.5s in, 0.3s out)
- All GUI is restored when closing the summon result
- The system handles cleanup automatically
