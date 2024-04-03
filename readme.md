

https://github.com/Oman395/godot-better-lighting-2d/assets/77183348/3de3df2e-4635-4d1d-bb75-7c6537f506bf


Relatively basic shader that's pretty much a drop-in with the existing godot 2d lighting system. Adds relatively cheap and significantly better looking soft shadows, a much better PBR system with zero additional textures, as well as removing the need to make annoying light textures-- all distance fade is calculated in-shader.

## Usage:

### Uniforms:

- light_count: I still hate that I need this, but there's no way to only apply ambient once (there probably is, but it would be very clunky). As a consequence, you need to provide the shader with the number of lights that should be visible to it.

- apply_distance_fade: Whether to apply distance fading to lights

- shadows: Whether to use shadows at all

- soft_shadows: Whether shadows should be hard or soft

- light_radius: Radius of all lights in the scene, in pixels. Affects soft shadows.

- shadow_march_count: Number of march steps to perform. Default to 256, lower values will have higher performance but risk visual glitches.

- shadow_march_min_step: Minimum distance of a single march step. Default to 0.2, I don't recommend touching this much-- it can improve clarity if combined with an increase in march count, or increase performance if increased by reducing the number of required steps, but carries a lot of potential for visual bugs.

- shadow_march_step_scale: Another thing I don't recommend touching. Default to 1.0, this will scale up/down the distance of each march-- lower values will increase shadow quality slightly, but will require a *lot* of increase to shadow_march_count if you want to avoid visual glitches. Higher values will improve performance by reducing the number of required steps, but has a very significant chance of causing light leak.

- ambient_amount: The value of "ambient" lighting, which is used to approximate global illuminations. Higher values will increase the "minimum" light levels.

- ambient_occlusion: Whether or not to apply ambient occlusion. For the unfamiliar, this applies simple shading to simulate how much indirect light (or ambient light) should be obscured by surrounding objects. Disabling this increases performance slightly, but not by a massive amount.

- ao_step_count: Ambient occlusion step count. Increases the radius and quality of the ambient occlusion; higher values should be paired with lower step sizes. Default to 6.

- ao_step_size: Ambient occlusion step size, in pixels. Increases the radius of the ambient occlusion. Default to 20.

- ao_influence: Ambient occlusion, by default, can obscure all indirect lighting; however, this allows that to be scaled. For example, a value of 0.5 would mean that as much as half of the indirect lighting can be removed. In practice, I find this looks a lot better than alternative methods. Default to 0.3.

### Texturing

- For regular textures, the default system can be used-- nothing special there.

- The same applies to normal maps, the default system can be used with no changes.

- I've done a bit of tweaks to specular maps. Rather than using them as simply the color of specular highlights, I've instead used them for all material properties; as a result, you can make *very* detailed materials, relatively easily.

  - R: The red channel represents how much "diffuse" lighting there should be. Diffuse lighting means any lighting that reflects uniformly off a surface; think walls, or paper.

  - G: The green channel represents how shiny "specular" lighting there should be. Specular lighting is lighting that is reflected; think plastic, or metal. Values closer to 0 will mean the specular highlight is "rougher", indicating a surface that's less shiny.

  - B: The blue channel represents how "metallic" the surface is. In this case, I'm modelling metallic very simply; generally speaking, metals will reflect light with the same color as the metal in its specular highlight, while things like tomatoes or plastic tends to reflect white light int its specular highlight. The metallic slider simply scales between white specular reflections at 0, to reflections the color of the material at 1.

  - A: This is a shame, and I really don't know why, but this is only adjustable through the "shininess" slider on the specular section. I've set it up to simply represent how much specular highlight there should be; unfortunately, this can't be variable along the texture. Note that, if needed, you can use a value of 1 in the G channel in order to disable specular highlight without this (by making the highlight infinitely small).

That's pretty much it for usage!

## Limitations:

- For now, DirectionalLight2D is not supported. This is because I have literally no clue how to make it look good.

- Lighting with a non-uniform output (I.E. a flashlight) still require a texture to help the shader know the bounds.

- Zooming in and out results in some slightly odd changes in the lighting (namely, the falloff scales, because ????); this is a bug, but I have no idea what's causing it.

- Individual lights can't have individual settings, such as radius; unfortunately, there's just not very much available to me in the light() function for each light. I could create a global array uniform, but I find that clunky, so for now I'm using this simplified system-- if enough people request, I might make a global array option.

## Recommendations:
In project settings->rendering->2d, set SDF scale and oversize essentially as high as possible while still maintaining your performance target; this will significantly improve shadow quality.

## Acknowledgements:

A lot of the soft shadow code was based on [IQ's incredible tutorial](https://iquilezles.org/articles/rmshadows/), which I highly recommend (as well as all of his other work) to anyone learning ray marching.

The AO code is based on a screenshot I found in a discord server; I'm not sure who the original author is, but if they light me know who they are I will add credit immediately.
