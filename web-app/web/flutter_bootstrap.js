{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({
        hostElement: document.getElementById('app'),
        canvasKitBaseUrl: 'canvaskit/',
      });
      await appRunner.runApp();
    } catch (error) {
      window.ridifyLoadingFailed();
      console.error('Ridify startup failed', error);
    }
  },
}).catch(window.ridifyLoadingFailed);
