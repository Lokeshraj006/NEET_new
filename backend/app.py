try:
    from .neet_core import app
except ImportError:
    from neet_core import app


if __name__ == '__main__':
    import uvicorn

    uvicorn.run('app:app', host='0.0.0.0', port=8000, reload=True)