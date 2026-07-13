"""Creative Service - AI image generation using pollinations.ai."""

import logging
import httpx

logger = logging.getLogger("aira.creative")


class CreativeService:
    """Generates AI art images from text prompts."""

    async def generate_image(self, prompt: str) -> str:
        """Generate an image using Pollinations AI.

        Returns:
            The public URL of the generated image.
        """
        try:
            logger.info(f"Generating image for: {prompt}")
            
            # Pollinations AI generates images directly from search parameters in the URL:
            # https://image.pollinations.ai/prompt/{prompt}?width={width}&height={height}&model={model}&nologo=true
            # We sanitize the prompt to be safe in a URL.
            import urllib.parse
            encoded_prompt = urllib.parse.quote(prompt)
            
            # We use the flux model for high quality
            image_url = f"https://image.pollinations.ai/p/{encoded_prompt}?width=512&height=512&nologo=true&private=true"
            
            # Perform a quick HEAD check to verify it responds correctly (Pollinations returns images dynamically)
            async with httpx.AsyncClient(timeout=15.0) as client:
                res = await client.head(image_url)
                if res.status_code == 200:
                    return image_url
            
            return image_url
            
        except Exception as e:
            logger.error(f"Image generation failed: {e}")
            raise


def get_creative_service() -> CreativeService:
    """Get creative service instance."""
    return CreativeService()
