// DLSS-имитация шейдера для MPC-HC / MPC-BE
// Апскейлинг с Bicubic + Contrast Adaptive Sharpening (CAS) + FXAA (анти-алиасинг)

sampler s0;
float4 ps_main(float2 tex : TEXCOORD0) : COLOR {
    float2 texSize;
    s0.GetDimensions(texSize.x, texSize.y);
    
    float2 upscaleFactor = float2(3840.0 / texSize.x, 2160.0 / texSize.y);
    if (upscaleFactor.x <= 1.0 && upscaleFactor.y <= 1.0) {
        upscaleFactor = float2(1.0, 1.0); // Не апскейлим, если уже 4K
    }
    
    float2 newUV = tex * upscaleFactor;
    float4 color = tex2D(s0, newUV);
    
    // Bicubic Filtering для плавности
    float4 c00 = tex2D(s0, newUV + float2(-1.0, -1.0) / texSize);
    float4 c10 = tex2D(s0, newUV + float2(1.0, -1.0) / texSize);
    float4 c01 = tex2D(s0, newUV + float2(-1.0, 1.0) / texSize);
    float4 c11 = tex2D(s0, newUV + float2(1.0, 1.0) / texSize);
    color = (color + c00 + c10 + c01 + c11) * 0.25;
    
    // Contrast Adaptive Sharpening (CAS)
    float sharpness = 0.6; // Можно менять для разной резкости
    float3 blur = (c00.rgb + c10.rgb + c01.rgb + c11.rgb) * 0.25;
    color.rgb = lerp(blur, color.rgb, sharpness);
    
    // FXAA (анти-алиасинг)
    float2 rcpFrame = 1.0 / texSize;
    float3 luma = float3(0.299, 0.587, 0.114);
    float lumaTL = dot(tex2D(s0, newUV + rcpFrame * float2(-1.0, -1.0)).rgb, luma);
    float lumaTR = dot(tex2D(s0, newUV + rcpFrame * float2(1.0, -1.0)).rgb, luma);
    float lumaBL = dot(tex2D(s0, newUV + rcpFrame * float2(-1.0, 1.0)).rgb, luma);
    float lumaBR = dot(tex2D(s0, newUV + rcpFrame * float2(1.0, 1.0)).rgb, luma);
    float lumaM  = dot(color.rgb, luma);
    float lumaMin = min(lumaM, min(min(lumaTL, lumaTR), min(lumaBL, lumaBR)));
    float lumaMax = max(lumaM, max(max(lumaTL, lumaTR), max(lumaBL, lumaBR)));
    float edgeThreshold = 0.125;
    if ((lumaMax - lumaMin) > edgeThreshold) {
        color.rgb = (c00.rgb + c10.rgb + c01.rgb + c11.rgb) * 0.25;
    }
    
    return color;
}

technique UpscaleCASFXAA {
    pass P0 {
        PixelShader = compile ps_3_0 ps_main();
    }
}
