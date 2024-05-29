//Credits to samirkumardas
//https://github.com/samirkumardas/pcm-player
//https://github.com/everywill

const unlockAudioContext = (audioCtx) => {
    window.audioCtx = audioCtx;
    if (audioCtx.state !== "suspended") return
    const b = document.body;
    const events = ["touchstart", "touchend", "mousedown", "keydown"];
    events.forEach((e) => b.addEventListener(e, unlock, false));
    function unlock() {
        audioCtx.resume().then(clean);
    }
    function clean() {
        // audioCtx.suspend().then(() => {})
        events.forEach((e) => b.removeEventListener(e, unlock));
    }
};

function FUPCMPlayer(option) {
    this.init(option);
}

FUPCMPlayer.prototype.init = function(option) {
    var defaults = {
        encoding: '16bitInt',
        channels: 1,
        sampleRate: 16000,
    };
    this.option = Object.assign({}, defaults, option);
    this.callback = this.option.callback;
    this.callbackTimeAhead = this.option.callbackTimeAhead;
    this.callbackOnEnd = this.option.callbackOnEnd;

    this.flush = this.flush.bind(this);
    this.maxValue = this.getMaxValue();
    this.typedArray = this.getTypedArray();
    this.playingBufferNode = null;
    this.scheduledBufferNode = null;
    this.createContext();
    this.resetState();
};

FUPCMPlayer.prototype.getMaxValue = function () {
    var encodings = {
        '8bitInt': 128,
        '16bitInt': 32768,
        '32bitInt': 2147483648,
        '32bitFloat': 1
    };

    return encodings[this.option.encoding] ? encodings[this.option.encoding] : encodings['16bitInt'];
};

FUPCMPlayer.prototype.getTypedArray = function () {
    var typedArrays = {
        '8bitInt': Int8Array,
        '16bitInt': Int16Array,
        '32bitInt': Int32Array,
        '32bitFloat': Float32Array
    };

    return typedArrays[this.option.encoding] ? typedArrays[this.option.encoding] : typedArrays['16bitInt'];
};

FUPCMPlayer.prototype.createContext = function() {
    this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();

    // context needs to be resumed on iOS and Safari (or it will stay in "suspended" state)
    this.audioCtx.resume();
    this.audioCtx.onstatechange = () => console.log('audioCtx.state', this.audioCtx.state);   // if you want to see "Running" state in console and be happy about it
    unlockAudioContext(this.audioCtx);

    this.gainNode = this.audioCtx.createGain();
    this.gainNode.gain.value = 1;
    this.gainNode.connect(this.audioCtx.destination);
    this.startTime = this.audioCtx.currentTime;
};

FUPCMPlayer.prototype.resetState = function() {
    this.playingStartTime = -1;
    this.lastGotTimestamp = 0;
    this.samples = new Float32Array();
    this.timeout = undefined;
    this.flag_request_stop = false;
    this.startTime = 0;
};

FUPCMPlayer.prototype.isTypedArray = function(data) {
    return (data.byteLength && data.buffer && data.buffer.constructor == ArrayBuffer);
};

FUPCMPlayer.prototype.feed = function(data) {
    if (!this.isTypedArray(data)) return;
    data = this.getFormatedValue(data);
    var tmp = new Float32Array(this.samples.length + data.length);
    tmp.set(this.samples, 0);
    tmp.set(data, this.samples.length);
    this.samples = tmp;
    if(!this.timeout) {
        this.flush();
    }
};

FUPCMPlayer.prototype.getFormatedValue = function(data) {
    var data = new this.typedArray(data.buffer),
        float32 = new Float32Array(data.length),
        i;

    for (i = 0; i < data.length; i++) {
        float32[i] = data[i] / this.maxValue;
    }
    return float32;
};

FUPCMPlayer.prototype.volume = function(volume) {
    this.gainNode.gain.value = volume;
};

FUPCMPlayer.prototype.destroy = function() {
    if (this.interval) {
        clearInterval(this.interval);
    }
    this.samples = null;
    this.audioCtx.close();
    this.audioCtx = null;
};

FUPCMPlayer.prototype.getTimestamp = function(elapsedMs) {
    if(this.playingStartTime >= 0) {
        if(!elapsedMs) {
            return this.audioCtx.currentTime - this.playingStartTime;
        }
        const ret = this.lastGotTimestamp;
        this.lastGotTimestamp += elapsedMs / 1000;
        return ret;
    }
    return 0;
};

FUPCMPlayer.prototype.setRequestStop = function() {
    this.flag_request_stop = true;
};

FUPCMPlayer.prototype.setOnEnd = function(cb) {
    this.onEnd = cb;
};

FUPCMPlayer.prototype.interrupt = function(cb) {
    this.scheduledBufferNode && this.scheduledBufferNode.stop(0);
    this.playingBufferNode && this.playingBufferNode.stop(0);
    this.ensuredClearTimeout();
    this.resetState();
    this.flag_request_stop = false;
};

// (即时超过超时时间也)确保会触发
FUPCMPlayer.prototype.ensuredSetTimeout = (function() {
    let startTimestamp;
    return function(fn, timeout, fn2, timeout2) {


        startTimestamp = performance.now();
        let checker;
        
        if (fn2) {
            let done = false;

            checker = (timestamp) => {
                if(timestamp - startTimestamp >= timeout2 && !done) {
                    done = true;
                    fn2(timestamp);
                }

                if(timestamp - startTimestamp >= timeout) {
                    this.timeout = undefined;
                    fn();
                } else {
                    this.timeout = requestAnimationFrame(checker);
                }
            };
        } else {
            checker = (timestamp) => {
                if (timestamp - startTimestamp >= timeout) {
                    this.timeout = undefined;
                    fn();
                } else {
                    this.timeout = requestAnimationFrame(checker);
                }
            };            
        }
        this.timeout = requestAnimationFrame(checker);
    }
})();

FUPCMPlayer.prototype.ensuredClearTimeout = function() {
    if(this.timeout) {
        cancelAnimationFrame(this.timeout);
        this.timeout = undefined;
    }
};

FUPCMPlayer.prototype.flush = function() {
    console.log('flush');

    if (!this.samples.length) {
        console.warn('End');
        if (this.callbackOnEnd) {
            console.warn('End');
            this.callbackOnEnd(false);
        }
        return;
    }
    
    var bufferSource = this.audioCtx.createBufferSource(),
        length = this.samples.length / this.option.channels,
        audioBuffer = this.audioCtx.createBuffer(this.option.channels, length, this.option.sampleRate),
        audioData,
        channel,
        offset,
        i,
        decrement;

    for (channel = 0; channel < this.option.channels; channel++) {
        audioData = audioBuffer.getChannelData(channel);
        offset = channel;
        decrement = 50;
        for (i = 0; i < length; i++) {
            audioData[i] = this.samples[offset];
            /* fadein */
            if (i < 50) {
                audioData[i] =  (audioData[i] * i) / 50;
            }
            /* fadeout*/
            if (i >= (length - 51)) {
                audioData[i] =  (audioData[i] * decrement--) / 50;
            }
            offset += this.option.channels;
        }
    }
    if (this.startTime < this.audioCtx.currentTime) {
        this.startTime = this.audioCtx.currentTime;
    }
    this.samples = new Float32Array();
    
    bufferSource.buffer = audioBuffer;
    bufferSource.connect(this.gainNode);

    bufferSource.start(this.startTime);
    this.playingBufferNode = this.scheduledBufferNode;
    this.scheduledBufferNode = bufferSource;
    if(this.playingStartTime < 0) {
        this.playingStartTime = this.startTime;
    }
    this.startTime += audioBuffer.duration;
    
    if(!this.flag_request_stop) {
        const nextTimeGap = (this.startTime - this.audioCtx.currentTime)*1000;
       
        this.ensuredSetTimeout(this.flush, nextTimeGap - 50, this.callback, nextTimeGap - this.callbackTimeAhead - 50);
        
    } else {
        this.flag_request_stop = false;
        bufferSource.onended = () => {
            this.resetState();
            this.onEnd && this.onEnd();
        };
    }
};

const rates = {
    "SignedInteger16": {type: '16bitInt', format: Int16Array},
    "SignedInteger8": {type: '8bitInt', format: Int8Array},
    "SignedInteger32": {type: '32bitInt', format: Int32Array}   
}

core.SampleRate = () => "SampleRate"

const fast = {};
fast.List = (args, env) => {
  return args.map((a) => interpretate(a, env))
}

fast.List.update = fast.List;

core.PCMPlayer = async (args, env) => {
  const initial = await interpretate(args[0], {...env, context: fast});
  const opts = await core._getRules(args, env);

  let encoding = rates["SignedInteger16"];

  if (args.length - (Object.keys(opts).length) > 1) {
    encoding = await interpretate(args[1], env);
    encoding = rates[encoding];
  }

  if (opts.FlushingTime) opts.FlushingTime = opts.FlushingTime / 1000.0;

  let call;

  if (opts.Event) {
    call = (time) => {
        server.kernel.emitt(opts.Event, time);
    }
  }

  env.local.state = () => {};
  
  var player = new FUPCMPlayer({
    encoding: encoding.type,
    channels: 1,
    sampleRate: opts.SampleRate || 44100,
    callback: call,
    callbackOnEnd: (time) => env.local.state(time),
    callbackTimeAhead: opts.TimeAhead || 200
 });

 env.local.encoding = encoding.format;
 env.local.player = player;

  //.feed(pcm_data);

  if (initial.length > 1) {
    player.feed(new encoding.format(initial));
  }

  if (opts.NoGUI) return; 
  env.element.classList.add(...('sm-controls cursor-default rounded-md 0 py-1 px-2 bg-gray-100 text-left text-gray-500 ring-1 ring-inset ring-gray-400 text-xs'.split(' ')));
  

  if (initial.length) {
    const uid = uuidv4();

    env.element.innerHTML = `
    <svg class="w-4 h-4 text-gray-500 inline-block mt-auto mb-auto" viewBox="0 0 24 24" fill="none">
<path class="group-hover:opacity-0" d="M3 11V13M6 10V14M9 11V13M12 9
V15M15 6V18M18 10V14M21 11V13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M3 11V13M6 8V16M9 10V14M12 7V17M15 4V20M18 9V15M21 11V13" class="opacity-0 group-hover:opacity-100" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg> <span id="${uid}-text" class="leading-normal pl-1">${initial.length/(opts.SampleRate || 44100)} sec</span>`;
    
    env.element.addEventListener('click', () => {
        env.local.state(true);
        player.feed(new encoding.format(initial));
    });

    const text = document.getElementById(uid + '-text');
    
    env.local.state = (state = false) => {
        if (env.local.prevState == state) return;

        if (state) {
            text.innerText = 'Playing';
        } else {
            text.innerText = 'No buffer';
        }

        env.local.prevState = state;
    }    

  } else {
    const uid = uuidv4();
    env.element.innerHTML = `
    <svg class="w-4 h-4 text-gray-500 inline-block mt-auto mb-auto" viewBox="0 0 24 24" fill="none">
<path id="${uid}-ico" d="M3 11V13M6 8V16M9 10V14M12 7V17M15 4V20M18 9V15M21 11V13" class="text-red-400" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg> <span class="leading-normal pl-1" id="${uid}-text">No buffer</span>`;
    
    const ico = document.getElementById(uid + '-ico');
    const text = document.getElementById(uid + '-text');
    
    env.local.state = (state = false) => {
        if (env.local.prevState == state) return;

        if (state) {
            ico.classList.remove('text-red-400');
            ico.classList.add('text-green-400');
            text.innerText = 'Playing';
        } else {
            ico.classList.add('text-red-400');
            ico.classList.remove('text-green-400');
            text.innerText = 'No buffer';
        }

        env.local.prevState = state;
    }
  }

}



core.PCMPlayer.update = async (args, env) => {
  const data = await interpretate(args[0], {...env, context: fast});
  env.local.state(true);
  env.local.player.feed(new env.local.encoding(data));
}

core.PCMPlayer.destroy = (args, env) => {
  env.local.player.destroy();
}


core.Sound = async (args, env) => {  
    const object = await interpretate(args[0], {
        ...env
    });
  
  
    env.element.classList.add(...('sm-controls cursor-default rounded-md 0 py-1 px-2 bg-gray-100 text-left text-gray-500 ring-1 ring-inset ring-gray-400 text-xs'.split(' ')));
  
    env.element.innerHTML = `
         <svg class="w-4 h-4 text-gray-500 inline-block mt-auto mb-auto" viewBox="0 0 24 24" fill="none">
     <path class="group-hover:opacity-0" d="M3 11V13M6 10V14M9 11V13M12 9
  V15M15 6V18M18 10V14M21 11V13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
     <path d="M3 11V13M6 8V16M9 10V14M12 7V17M15 4V20M18 9V15M21 11V13" class="opacity-0 group-hover:opacity-100" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
     </svg> <span class="leading-normal pl-1">${object.length} sec</span>`;
  
    //const targetRate = ctx.sampleRate;

    const player = new FUPCMPlayer({
        encoding: object.type,
        channels: 1,
        sampleRate: object.rate,
        callback: console.log,
        callbackTimeAhead: 50
     });

     env.local.player = player;
  
    env.element.addEventListener('click', () => {
        player.feed(object.data);
    })
    // start the source playing
    //env.element.click();
    //
  }

  core.Sound.destroy = (args, env) => {
    env.local.player.destroy();
  }
  
  
  
  core.SampledSoundList = async (args, env) => {
    //assume 32bit float

    const data = await interpretate(args[0], {...env, context: fast});
    const rate = await interpretate(args[1], env);
  
    
    const length = data.length / rate;
  
    return {
        data: new Float32Array(data),
        rate: rate,
        type: '32bitFloat',
        length: length
    };
  }