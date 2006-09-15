
// Web-form-based Flash Movie Controls


function hiliteButton() {
  var id = arguments[0];
  var button;
  if (arguments.length > 1) {
    // cancel existing hilited buttons
    for (var i=1; i<arguments.length; i++) {
      button = document.getElementById(arguments[i]);
      button.className = 'red-button';
    }
  }
  // highlight new button
  button = document.getElementById(id);
  button.className = 'blue-button';
}

var interval;

function PlayMovie(length) {
  // start playing movie
  var movie=window.document.movie;
  movie.Play();

  // animate progress bar
  if (length > 0) {
    var i = 0;
    var delay = 3000;
    interval = setInterval(setStep, delay);
  }
}

function setStep() {
  var movie = window.document.movie;
  var length = movie.TotalFrames();
  var current = movie.TCurrentFrame('/');
  last_step = parseInt((current / length) * 10) + 4;
  if (last_step > 4) {
    hiliteButton('control_movie_'+last_step, 'control_movie_2', 'control_movie_4', 'control_movie_5', 'control_movie_6', 'control_movie_7', 'control_movie_8', 'control_movie_9', 'control_movie_10', 'control_movie_11', 'control_movie_12', 'control_movie_13', 'control_movie_14');
  }
  return current;
}

function StopMovie() {
  var movie = window.document.movie;
  movie.StopPlay();
  if (interval) {
    clearInterval(interval);
  }
}

function RewindMovie() {
  var movie = window.document.movie;
  movie.Rewind();
}

function EndOfMovie() {
  var movie = window.document.movie;
  var last = movie.TotalFrames(); 
  movie.GotoFrame(last);    
}

function SkipToFrame(frame) {
  var movie = window.document.movie;
  var length = movie.TotalFrames();
  var current = movie.TCurrentFrame('/');
  movie.GotoFrame(frame);    
  last_step = parseInt((current / length) * 10) + 4;
  if (last_step > 4) {
    hiliteButton('control_movie_'+last_step);
  }
  movie.Play();
}


function ZoominMovie() {
  var movie = window.document.movie;
  movie.Zoom(90);
}

function ZoomoutMovie() {
  var movie = window.document.movie;
  movie.Zoom(110);
}


