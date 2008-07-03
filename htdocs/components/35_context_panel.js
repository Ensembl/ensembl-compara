/***********************************************************************
**                                                                    **
**  Makes the list of transcripts collapsible                         **
**                                                                    **
**  Public functions: None...                                         **
**                                                                    **
***********************************************************************/

  function __init_transcript_dropdown(table_id) {
/** Initialize link to either collapse or expand transcript list.

    PRIVATE - should only be executed once on page load
**/

// If no transcripts OR already generated link so return....
    if( !$(table_id) || $(table_id + '_link') ) return;

    var initial_open = 1;
    var txt_on       = 'hide ' + table_id;
    var txt_off      = 'show ' + table_id;

    $(table_id + '_text').appendChild(
      Builder.node( 'div',
        { id: table_id + '_link' }, 
        [ initial_open ? txt_off : txt_on ]
      )
    );
    if( initial_open != 1 ) $(table_id).hide();
    Event.observe($(table_id + '_link'),'click',function(event){
      $(table_id).toggle();
      var T = $(table_id + '_link');
      T.innerHTML = T.innerHTML == txt_off ? txt_on : txt_off;
    });
  }

  Event.observe(window, 'load', __init_table_dropdown('transcripts'));
  Event.observe(window, 'load', __init_table_dropdown('locations') );
