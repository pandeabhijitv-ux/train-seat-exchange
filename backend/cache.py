"""
Redis Caching Layer
Cache frequently accessed data to reduce database load
"""
import redis
from typing import Optional, Any
import json
from config import settings

class CacheService:
    def __init__(self):
        self.redis_client = None
        if hasattr(settings, 'redis_url') and settings.redis_url:
            try:
                self.redis_client = redis.from_url(
                    settings.redis_url,
                    decode_responses=True
                )
                self.redis_client.ping()
                print("✅ Redis cache connected")
            except:
                print("⚠️ Redis not available, caching disabled")
    
    def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        if not self.redis_client:
            return None
        
        try:
            value = self.redis_client.get(key)
            return json.loads(value) if value else None
        except:
            return None
    
    def set(self, key: str, value: Any, ttl: int = 300):
        """Set value in cache with TTL (default 5 minutes)"""
        if not self.redis_client:
            return False
        
        try:
            self.redis_client.setex(
                key,
                ttl,
                json.dumps(value)
            )
            return True
        except:
            return False
    
    def delete(self, key: str):
        """Delete from cache"""
        if not self.redis_client:
            return
        
        try:
            self.redis_client.delete(key)
        except:
            pass
    
    def clear_pattern(self, pattern: str):
        """Clear all keys matching pattern"""
        if not self.redis_client:
            return
        
        try:
            keys = self.redis_client.keys(pattern)
            if keys:
                self.redis_client.delete(*keys)
        except:
            pass


cache = CacheService()


# Decorator for caching function results
def cached(ttl: int = 300):
    """Cache decorator for functions"""
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # Generate cache key from function name and arguments
            cache_key = f"{func.__name__}:{str(args)}:{str(kwargs)}"
            
            # Try to get from cache
            cached_value = cache.get(cache_key)
            if cached_value is not None:
                return cached_value
            
            # Execute function
            result = await func(*args, **kwargs)
            
            # Store in cache
            cache.set(cache_key, result, ttl)
            
            return result
        return wrapper
    return decorator
