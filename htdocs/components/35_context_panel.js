/***********************************************************************
**                                                                    **
**  Makes the list of transcripts collapsible                         **
**                                                                    **
**  Public functions: None...                                         **
**                                                                    **
***********************************************************************/

  function __init_transcript_dropdown() {
/** Initialize link to either collapse or expand transcript list.

    PRIVATE - should only be executed once on page load
**/

// If no transcripts OR already generated link so return....
    if( !$('transcripts') || $('transcripts_link') ) return;

    var initial_open = 1;
    var txt_on       = 'show transcripts';
    var txt_off      = 'hide transcripts';

    $('transcripts_text').appendChild(
      Builder.node( 'div',
        { id: 'transcripts_link' }, 
        [ initial_open ? txt_off : txt_on ]
      )
    );
    if( initial_open != 1 ) $('transcripts').hide();
    Event.observe($('transcripts_link'),'click',function(event){
      $('transcripts').toggle();
      var T = $('transcripts_link');
      T.innerHTML = T.innerHTML == txt_off ? txt_on : txt_off;
    });
  }

  Event.observe(window, 'load', __init_transcript_dropdown );
