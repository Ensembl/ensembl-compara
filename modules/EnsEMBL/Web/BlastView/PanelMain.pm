#----------------------------------------------------------------------
#
# Builder for main panel of Mart system
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::PanelMain;

use strict;
use Carp;
use HTML::Template;

use EnsEMBL::Web::BlastView::Panel;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Panel);

my %cells;

# 20 by 20 spacer
#$cells{X}= qq(
#    <TD height=20 width=20 bgcolor='<TMPL_VAR MAIN_BG_COLOR>' colspan=1
#    ><IMG src="/img/blank.gif" height="20" width="20" /></TD>);

# 1 by 10 spacer (BG)
$cells{V}= qq(
    <TD height=10 width=1 class="main_panel_bg" colspan=1
    ><IMG src="/img/blank.gif" height=7 width=1 /></TD>);

# 1 by 5 spacer (BG)
$cells{W}= qq(
    <TD height=5 width=1 class="main_panel_bg" colspan=1
    ><IMG src="/img/blank.gif" height=5 width=1 /></TD>);

# 20 by 1 spacer (BG)
$cells{H}= qq(
    <TD height=1 width=10 class="main_panel_bg" colspan=1
    ><IMG src="/img/blank.gif" height=1 width=10 /></TD>);

# 5 by 1 spacer (BG)
$cells{i}= qq(
    <TD height=1 width=5 class="main_panel_bg" colspan=1
      ><IMG src="/img/blank.gif" height=1 width=5 /></TD>);

# 5 by 1 spacer (FG)
$cells{x}= qq(
    <TD height=1 width=5 class="main_panel_fg" colspan=1
    ><IMG src="/img/blank.gif" height=1 width=5 /></TD>);

# 1 by 5 spacer (FG)
$cells{v}= qq(
    <TD height=5 width=1 class="main_panel_fg" colspan=1
    ><IMG src="/img/blank.gif" height=5 width=1 /></TD>);

# 10 by 1 spacer  (FG)
$cells{g}= qq(
    <TD height=1 width=10 class="main_panel_fg" colspan=1
    ><IMG src="/img/blank.gif" height=1 width=10 /></TD>);

# 5 by 1 spacer  (FG)
$cells{h}= qq(
    <TD height=1 width=5 class="main_panel_fg"  colspan=1
    ><IMG src="/img/blank.gif" height=1 width=5 /></TD>);

# 1-pixel border
$cells{_}= qq(
    <TD height=1 width=1 class="main_panel_border" colspan=1
    ><IMG src="/img/blank.gif" height=1 width=1 /></TD>);

# Label cell (yellow bg)
$cells{T}= qq(
    <TD class='block_head' colspan=1>%s</TD>);

# Text cell (yellow bg)
$cells{d}= qq(
    <TD class='panel_text' colspan=1>%s</TD>);

# Left align Label cell (yellow bg)
$cells{L}= qq(
    <TD class='panel_big_head' colspan=1>%s</TD>);

# Right align Label cell (yellow bg)
$cells{R}= qq(
    <TD class='panel_head' align='right' colspan=1>%s</TD>);

# Description Label cell (yellow bg)
$cells{D}= qq(
    <TD class='panel_head' colspan=1>%s</TD>);

# Label cell (white bg left align 50%)
$cells{t}= qq(
    <TD class="main_panel_fg" width='50%%' valign="top" colspan=1>%s</TD>);

# Label cell (white bg left align 1% ) - Checkbox/radio cell
$cells{o}= qq(
    <TD class="main_panel_fg" width='1%%' valign="top" colspan=1>%s</TD>);

# Label cell (white bg left align 25%)
$cells{a}= qq(
    <TD class="main_panel_fg" width='25%%' colspan=1>%s</TD>);

# Label cell (white bg left align - unsized)
$cells{u}= qq(
    <TD class="main_panel_fg" nowrap colspan=1>%s</TD>);

# Label cell (white bg left align unsized 2 placeholders)
$cells{y}= qq(
    <TD class="main_panel_fg"  colspan=1>%s&nbsp;%s</TD>);

# Label cell (white bg right align)
$cells{r}= qq(
    <TD class="main_panel_fg" align='right' colspan=1>%s</TD>);

# Label cell (white bg center align)
$cells{c}= qq(
    <TD class="main_panel_fg" align='center' width='50%%' colspan=1>%s</TD>);
# Label cell (yellow bg left align)
$cells{Z}= qq(
    <TD class="main_panel_fg" colspan=1>%s</TD>);
# Label cell (bg color left align
$cells{Y}= qq(
    <TD class="main_panel_bg_left" colspan=1>%s</TD>);
# Cell with 2 elems separated by a <BR /> (white bg)
$cells{B}= qq(
    <TD class="main_panel_fg" colspan=1>%s&nbsp;%s<BR />%s&nbsp;%s</TD>);

# Warning text cell
$cells{p} = qq(
    <TD class='entry_warning' colspan=1>%s</TD>);

# Info text
$cells{q} = qq(
    <TD class='main_panel_fg_bold' colspan=1>%s</TD>);

# Warning image cell
#$cells{P} = qq(
#    <TD height=20 width=20 colspan=1
#    ><A name='warning'
#    ><IMG src='/img/blastview/warn.gif' height=20 width=20></TD>);

# Info image
#$cells{I} = qq(
#    <TD height=20 width=20 colspan=1
#    ><A name='info'
#    ><IMG src='/img/blastview/info.gif' height=20 width=20></TD>);
#cells for line under tabs
#$cells{Z}=qq(
 #   <TD height=1 width=10 bgcolor='#999999' colspan=1
  #  ><IMG src='' height=1 width=10></TD>);
#$cells{l}=qq(
 #   <TD height=1 width=1 bgcolor='#FFFFE7' colspan=1
  #  ><IMG src='' height=1 width=1></TD>);

my %rows;

# Padding row (outer, yellow bg)
#$rows{panel_padding } = 'HVVVVVVVVVVVVVH';
$rows{panel_padding } = 'HVVVVVVVVVVVVVVVH';

# Header row (outer, yellow bg)
#$rows{panel_header  } = 'HDDDDDDDDDDDDDH';
$rows{panel_header  } = 'HDDDDDDDDDDDDDDDH';

# Text row (outer, yellow bg)
#$rows{panel_text    } = 'HdddddddddddddH';
$rows{panel_text    } = 'HdddddddddddddddH';

# Panel Header Image row
#$rows{panel_image   } = 'HLLLLLLRRRRRRRH';
$rows{panel_image   } = 'HLLLLLLLRRRRRRRRH';

# Ruled line (yellow bg)
#$rows{block_rule   }  = 'H_____________H';
$rows{block_rule   }  = 'H_______________H';

# Padding row (inner, yellow bg)
#$rows{block_padding}  = 'HHWWWWWWWWWWWHH';
$rows{block_padding}  = 'H_gvvvvvvvvvvvg_H';

# Header row (inner, yellow bg)
#$rows{block_header } = 'HHTTTTTTTTTTTHH';
$rows{block_header }  = 'H_gTTTTTTTTTTTg_H';


# Ruled line (white bg)
#$rows{entry_rule   } = 'HH___________HH';
$rows{entry_rule   }  = 'H_g___________g_H';

# Padding row (white bg)
$rows{entry_padding}  = 'H_gxhvvvvvvvhxg_H';

# Header row (white bg)
$rows{entry_header }  = 'H_gxhqqqqqqqhxg_H';

# Text row (white bg) - 1 col (ttt)
$rows{entry_info   } = 'H_gxhttttttthxg_H';

# Text row (white bg) - 2 col
$rows{entry_info2  } = 'H_gxhthttttthxg_H';

# Text row (white bg) - 3 col
$rows{entry_info3  } = 'H_gxhththttthxg_H';

# Text row (white bg) - 4 col
$rows{entry_info4  } = 'H_gxhuhuhuhuhxg_H';

# Select row (white bg) - form+label+form+label
$rows{entry_select } = 'H_gxhohthohthxg_H';

# row for 4 exprt tabs
#$rows{tab_select } =   'ZZZZZZZZZZZZZZZZZ';
$rows{tab_select } =   'YYYYYYYYYYYYYYYYY';

#row for lines below tabs
$rows{tab_lines} =     'HHHHHHHHHHHHHHHHH';

# Element row (white bg) - 2 col (oht + ooo)
$rows{entry_filter } = 'H_gxhohthooohxg_H';

# Element  row (white bg) - 1 col (oht)
$rows{entry_filter2} = 'H_gxhohttttthxg_H';

# Element row (white bg) - 2 col (rrr ooo)
$rows{entry_filter3} = 'H_gxhrrrhooohxg_H';



# Element row (white bg) - 2 col (oht + BBB)
$rows{entry_filter4} = 'H_gxhohthBBBhxg_H';

# Element row (white bg) - 2 col (ttt + ttt)
$rows{entry_filter5} = 'H_gxhttthttthxg_H';

# Element row (white bg) - 2 col (oht + oht)
$rows{entry_filter6} = 'H_gxhohthohthxg_H';

# Element row (white bg) - 1 col (ttt)
$rows{entry_filter7} = 'H_gxhttttttthxg_H';

# Element row (white bg) - 2 col (oht + yyy)
$rows{entry_filter8} = 'H_gxhohthyyyhxg_H';

# Element row (white bg) - 2 col (yyy + oht)
$rows{entry_filter9} = 'H_gxhohthyyyhxg_H';

# Element row (white bg) - 2 col (yyy + oht)
$rows{entry_filter10} = 'H_gxhyyyhyyyhxg_H';

$rows{entry_filter11} = 'H_gxhohtohoohxg_H';

# Element row (white bg) - 2 col (ZZZ ooo)
$rows{entry_filter12} = 'H_gxhZZZZZZZhxg_H';

# Element row (white bg) - 4 col (hth)
#$rows{entry_filter13} = 'H_gxhththththxg_H';

# Button row (white bg) - form+label+form(*2)+label(*2)
$rows{entry_button } = 'H_gxhccchccchxg_H';

# Centered row (white bg) single TD, centered
$rows{entry_center } = 'H_gxhccccccchxg_H';


# Warning row
$rows{warning      } = 'H_gxhppppppphxg_H';

# Alignment rows
$rows{align1       } = 'HHHHidddddddiHHHH';
$rows{align2       } = 'HHHHididididiHHHH';

my $panel = EnsEMBL::Web::BlastView::Panel->new({ rowdefs=>\%rows, celldefs=>\%cells});

#----------------------------------------------------------------------
# Creates a new MainPanel object
sub new{

  my $class = shift;
  my $self = {
	      panel     => $panel,
	      data      => [],
	      pointers  => { block => 0,
			     entry => 0,
			     form  => 0 },

	      panel_top_row     => $panel->get_row('panel_padding'),
	      panel_base_row    => $panel->get_row('panel_padding'),
	      panel_padding_row => $panel->get_row('panel_padding'),

	      block_top_row     => join( '',
					 $panel->get_row('block_rule').
					 $panel->get_row('block_padding') ),
	      block_base_row    => join( '',
					 $panel->get_row('block_padding'),
					 $panel->get_row('block_rule') 
				       ),
	      block_padding_row => $panel->get_row('block_padding'),

	      entry_padding_row => '',#$panel->get_row('entry_padding') ,
	      entry_top_row     => join( 
					'',
					$panel->get_row('entry_rule'),
					$panel->get_row('entry_padding') 
				       ),
	      entry_base_row    => join(
					'',
					#$panel->get_row('entry_padding'),
					#$panel->get_row('entry_rule') 
				       ),

	      html_tmpl => '',
	     };

  bless $self, $class;

  return $self;
}

#----------------------------------------------------------------------
#
sub gen_warn_placeholder{
  my $self = shift;
  my $form = shift;
  return sprintf( $self->get_row('warning'),
		  $self->_gen_base_form( -type => 'WARNING',
					 -name => $form, ) );
}

#----------------------------------------------------------------------
# Adds the image butons at the top left and right of the panel
# Needs an array of two hashrefs, each with name, value and src keys
sub add_panel_image{
  my $self         = shift;
  my $title_meta   = shift;
  my @buttons_meta = @_;
#  my $meta2 = shift;
#  my $meta3 = shift;
#  my $meta4 = shift;

  my @buttons;
  foreach( @buttons_meta ){
    if( $_->{-src} ){
      push( @buttons, 
	    $self->_gen_base_form( -type =>'image',
				   -name =>$_->{-name},
				   -value=>$_->{-value}, 
				   -src  =>$_->{-src} ) );
    }
    else{ push( @buttons, '&nbsp' ) }
  }
  my $form = sprintf( $self->get_row('panel_image'),
		      $title_meta->{LABEL} || '&nbsp;',
		      join '', @buttons);
  $self->add_block( $form );
  return 1;
}

#----------------------------------------------------------------------
# Adds a warning row to the panel
sub add_warning{
  my $self = shift;
  my $meta = shift;
  my $label = $meta->{LABEL} || 'Unknown warning';
  $self->add_block( sprintf( $self->get_row('warning'), $label ) );
  return 1;
}

#----------------------------------------------------------------------
# Adds an info row to the panel
sub add_info   {
  my $self = shift;
  my $meta = shift;
  my $label = $meta->{LABEL} || 'Unknown';
  $self->add_block( sprintf( $self->get_row('entry_info'), $label ) );
  return 1;
}

#----------------------------------------------------------------------
# Adds a text row to the panel
sub add_panel_text   {
  my $self = shift;
  my $meta = shift;
  my $label = $meta->{LABEL} || 'Unknown';
  $self->add_block( sprintf( $self->get_row('panel_text'), $label ) );
  return 1;
}

#----------------------------------------------------------------------
#
sub get_form_label{
  my $self = shift;
  my $data = shift;
  my $tmpl = $self->get_row('entry_info');
  return sprintf( $tmpl, $data );
}

#----------------------------------------------------------------------
#
sub get_entry_result{
  my $self = shift;
  my @data = @_;
  my $tmpl = $self->get_row('entry_info4');
  return sprintf( $tmpl, map{ "<SMALL>$_</SMALL>" } @data );

}
#----------------------------------------------------------------------
#
sub gen_checkbox_group{
  my $self = shift;
  my @entry_objs = @_;
  my $type = 'CHECKBOX';
  return $self->_gen_specified_group( $type, @_ );
}
#----------------------------------------------------------------------
#
sub gen_checkbox_with_label{
  my $self = shift;
  my @entry_objs = @_;
  my $tmpl = $self->get_row('entry_filter2');
  my $check = $self->_gen_element( 'CHECKBOX', $entry_objs[0] );
  return sprintf( $tmpl, $check, $entry_objs[0]->get_label );
}
#----------------------------------------------------------------------
#
sub gen_radio_group{
  my $self = shift;
  my @entry_objs = @_;
  my $type = 'RADIO';
  return $self->_gen_specified_group( $type, @_ );
}
#----------------------------------------------------------------------
#
sub gen_radio_group_vertical{
  my $self = shift;
  my @entry_objs = @_;
  my $type = 'RADIO';
  return $self->_gen_specified_group_vertical( $type, @_);
}
#----------------------------------------------------------------------
#
sub _gen_specified_group{
  my $self = shift;
  my $form_type = shift;
  my @form_entries = @_;

  my $tmpl  = $self->get_row('entry_select');
  my $htmpl = $self->get_row('entry_header');
  my $html;
  
  my $i = 0;
  while( $i < @form_entries ){
    

    if( ref( $form_entries[$i] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	$form_entries[$i]->get_label && 
	! $form_entries[$i]->get_value ){ # Header row

      if( ref( $form_entries[$i+1] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	  $form_entries[$i+1]->get_label and 
	  ! $form_entries[$i+1]->get_value ){ # Next row header too! skip this
	$i++;
	next;
      }
      # Print header and carry on
      if( $i>0 ){ $html .= $self->get_row('entry_padding') }
      $html .= sprintf( $htmpl, $form_entries[$i]->get_label );
      $i++;
      next;
    }
    
    # Construct row of boxes
    my @bases;
    my @labels;
    foreach my $form_entry( $form_entries[$i], $form_entries[$i+1] ){
      if(  ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	   $form_entries[$i]->get_label and 
	   ! $form_entries[$i]->get_value ){ # Header row, skip to next
	push( @bases, '' );
	push( @labels, '' );
	next;
      }
      my $base;
      if( ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry' ){
	if( $form_entry->get_value ){
	  $base = $self->_gen_base_form( -type  => $form_type,
					 -name  => $form_entry->get_cgi_name,
					 -value => $form_entry->get_value,
					 get_extra( $form_entry ) );
	}
	push( @bases, $base );
	push( @labels, $form_entry->get_label );
      }
      $i++;
    }
    $html .= sprintf( $tmpl, 
		      shift @bases || '&nbsp', shift @labels || '&nbsp',
		      shift @bases || '&nbsp', shift @labels || '&nbsp', );
  }
  
  return $html;
}

#----------------------------------------------------------------------
sub gen_2col_group{
  my $self = shift;
  my @form_entries = @_;

  my %types = ( RADIO    => 'oht',
		CHECKBOX => 'oht',
		SELECT   => 'yyy',
		TEXT     => 'yyy',
	        TEXTAREA => 'yyy',
		BUTTON   => 'yyy',
		FILE     => 'yyy',
		#LABEL    => 'ttttttt',
		#HIDDEN   => '' 
	      );
  my %rows =  ( ohtoht=>$self->get_row('entry_filter6'),
		ohtyyy=>$self->get_row('entry_filter8'),
		yyyoht=>$self->get_row('entry_filter9'),
		yyyyyy=>$self->get_row('entry_filter10'), );


  my $i = 0;
  my $html = '';
  while( $i < @form_entries ){
    my $entry_left  = $form_entries[$i];
    my $entry_right = $form_entries[$i+1];

    if( $entry_right ){ # 2-cols
      my $type_left  = $entry_left->get_type  || 'CHECKBOX';
      my $type_right = $entry_right->get_type || 'CHECKBOX';
      my $tmpl = $rows{$types{$type_left}.$types{$type_right}};
      $html .= sprintf( $tmpl, 
			$self->_gen_element( $type_left, $entry_left ),
			$entry_left->get_label,
			$self->_gen_element( $type_right, $entry_right ),
			$entry_right->get_label );
    }
    else{ # Left col only
      my $type_left  = $entry_left->get_type  || 'CHECKBOX';
      my $tmpl = $rows{$types{$type_left}.'yyy'};
      $html .= sprintf( $tmpl, 
			$self->_gen_element( $type_left, $entry_left ),
			$entry_left->get_label );
    }
    $i+=2; #Skip 2
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_1col_group{
  my $self = shift;
  my @form_entries = @_;
  my $tmpl = $self->get_row('entry_filter3');
  my $html = '';
  foreach my $entry( @form_entries ){
    $html .= sprintf( $tmpl, 
		      $entry->get_label,
		      $self->_gen_element( $entry->get_type, $entry ),)
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_2control_group{
  my $self = shift;
  my @form_entries = @_;
  
  my $tmpl  = $self->get_row('entry_filter5');
  my $htmpl = $self->get_row('entry_header');
  my $html;
  
  my $i = 0;
  while( $i < @form_entries ){
    
    if( ref( $form_entries[$i] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
        $form_entries[$i]->get_label && 
        ! $form_entries[$i]->get_value &&
        ! $form_entries[$i]->get_options ){ # Header row
      
      if( ref( $form_entries[$i+1] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
          $form_entries[$i+1]->get_label and 
          ! $form_entries[$i+1]->get_value &&
          ! $form_entries[$i]->get_options ){ # Next row header too! skip this
        $i++;
        next;
      }
      # Print header and carry on
      if( $i>0 ){ $html .= $self->get_row('entry_padding') }
      $html .= sprintf( $htmpl, $form_entries[$i]->get_label );
      $i++;
      next;
    }
    
    # Construct row of boxes
    my @bases;
    my @labels;
    foreach my $form_entry( $form_entries[$i], $form_entries[$i+1] ){
      if(  ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
           $form_entries[$i]->get_label and 
           ! $form_entries[$i]->get_value and
           ! $form_entries[$i]->get_options ){ # Header row, skip to next
        push( @bases, '' );
        push( @labels, '' );
        next;
      }
      my $base;
      if( ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry' ){
	if( $form_entry->get_value ){
	  my $type = $form_entry->get_type || 'CHECKBOX';
	  $base = $self->_gen_element( $type, $form_entry );
	}
	push( @bases, $base );
	push( @labels, $form_entry->get_label );
      }
      $i++;
    }
    $html .= sprintf( $tmpl, 
		      (shift @bases || '&nbsp;') . (shift @labels || '&nbsp;'),
		      (shift @bases || '&nbsp;') . (shift @labels || '&nbsp;'),);
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_4control_group{
  my $self = shift;
  my @form_entries = @_;

  my $tmpl  = $self->get_row('entry_info4');
  my $htmpl = $self->get_row('entry_header');
  my $html;
  my $i = 0;
  while( $i < @form_entries ){
    
    if( ref( $form_entries[$i] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	$form_entries[$i]->get_label && 
	! $form_entries[$i]->get_value ){ # Header row
      
      if( ref( $form_entries[$i+1] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	  $form_entries[$i+1]->get_label and 
	  ! $form_entries[$i+1]->get_value ){ # Next row header too! skip this
	$i++;
	next;
      }
      # Print header and carry on
      if( $i>0 ){ $html .= $self->get_row('entry_padding') }
      $html .= sprintf( $htmpl, $form_entries[$i]->get_label );
      $i++;
      next;
    }

    # Construct row of boxes
    my @bases;
    my @labels;
    foreach my $form_entry( @form_entries[$i..$i+3] ){
      if(  ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	   $form_entries[$i]->get_label and 
	   ! $form_entries[$i]->get_value ){ # Header row, skip to next
	push( @bases, '' );
	push( @labels, '' );
	next;
      }
      my $base;
      if( ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry' ){
	if( $form_entry->get_value ){
	  my $type = $form_entry->get_type || 'CHECKBOX';
	  $base = $self->_gen_element( $type, $form_entry );
	}
	push( @bases, $base );
	push( @labels, $form_entry->get_label );
      }
      $i++;
    }
    $html .= sprintf( $tmpl, 
		      (shift @bases || '&nbsp') . (shift @labels || '&nbsp'),
		      (shift @bases || '&nbsp') . (shift @labels || '&nbsp'),
		      (shift @bases || '&nbsp') . (shift @labels || '&nbsp'),
		      (shift @bases || '&nbsp') . (shift @labels || '&nbsp'),
		    );
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub _gen_specified_group_vertical{
  my $self = shift;
  my $form_type = shift;
  my @form_entries = @_;

  my $tmpl  = $self->get_row('entry_filter2');
  my $htmpl = $self->get_row('entry_header');
  my $html;
  
  my $i = 0;
  while( $i < @form_entries ){
    

    if( ref( $form_entries[$i] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	$form_entries[$i]->get_label && 
	! $form_entries[$i]->get_value ){ # Header row

      if( ref( $form_entries[$i+1] ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	  $form_entries[$i+1]->get_label and 
	  ! $form_entries[$i+1]->get_value ){ # Next row header too! skip this
	$i++;
	next;
      }
      # Print header and carry on
      if( $i>0 ){ $html .= $self->get_row('entry_padding') }
      $html .= sprintf( $htmpl, $form_entries[$i]->get_label );
      $i++;
      next;
    }
    
    # Construct row of boxes
    my @bases;
    my @labels;
    foreach my $form_entry( $form_entries[$i]){
      if(  ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry'  and 
	   $form_entries[$i]->get_label and 
	   ! $form_entries[$i]->get_value ){ # Header row, skip to next
	push( @bases, '' );
	push( @labels, '' );
	next;
      }
      my $base;
      if( ref( $form_entry ) eq 'EnsEMBL::Web::BlastView::MetaFormEntry' ){
	if( $form_entry->get_value ){
	  $base = $self->_gen_base_form( -type  => $form_type,
					 -name  => $form_entry->get_cgi_name,
					 -value => $form_entry->get_value,
					 get_extra( $form_entry ) );
	}
	push( @bases, $base );
	push( @labels, $form_entry->get_label );
      }
      $i++;
    }
    $html .= sprintf( $tmpl, 
		      shift @bases || '&nbsp', shift @labels || '&nbsp',);
  }
  return $html;
}

#----------------------------------------------------------------------
# E.g. for attribute/sequence switching.
sub gen_button_group{
  my $form_type = 'IMAGE2';
  my $self = shift;
  my @entries = @_;

  my $tmpl = $self->get_row('entry_center');
  my $spacer = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';

  my @bases;
  foreach my $entry( @entries ){

#    my $src = EnsEMBL::Web::BlastView::Panel::IMG_ROOT_ROVER.'/'.$form->get_src;
    my $base = $self->_gen_base_form( -type  => $form_type,
				      -name  => $entry->get_cgi_name,
				      -value => $entry->get_value,
				      get_extra( $entry ) );
    push( @bases, $base );
  }

  my $hide = $self->_gen_base_form( -type  => 'hidden2',
				    -name  => $entries[0]->get_cgi_name );

  return sprintf( $tmpl, 
		  ( join( $spacer, @bases ).$hide ) );
}

#----------------------------------------------------------------------
# E.g. for attribute/sequence switching.
sub gen_tab_group{
  my $form_type = 'IMAGE2';
  my $self = shift;
  my @form_entries = @_;

  my $tmpl = $self->get_row('tab_select');
  my $spacer = '';
  #my $finalline = $self->get_row('tab_lines');
  my $html;

  my @bases;
  foreach my $form( @form_entries ){

    my $base = $self->_gen_base_form( -type  => $form_type,
				      -name  => $form->get_cgi_name,
				      -value => $form->get_value,
				      get_extra( $form ) );
    push( @bases, $base );
  }
  
  my $src = EnsEMBL::Web::BlastView::Panel::IMG_ROOT_ROVER;
  #With Will's tab images
  #$html .= sprintf( $tmpl, 
	#	    "<IMG src=${src}/tab_left.gif />".
		#    join( $spacer, @bases ). 
		 #   "<IMG src=${src}/tab_right.gif />");
  $html .= sprintf( $tmpl, 
		  ( join( $spacer, @bases ) ) );
  #$html .= $finalline;
  return $html;
}

#----------------------------------------------------------------------
# For generating the SNP filters. 
# Shares a lot with gen_checkbox_group, except that the first line consists 
# of a pair of range text boxes
#

sub gen_experiment_type_group {
  my $self = shift;
  my @entry_objs = @_;
  #my $check_with_label  = $self->gen_check_with_label( shift @entry_objs);
  my $hidden = $self->gen_hidden(pop @entry_objs);
  #return $check_with_label.$self->_gen_specified_group( 'CHECKBOX', @entry_objs ).$hidden;
  return $self->_gen_specified_group( 'CHECKBOX', @entry_objs ).$hidden;
}

sub gen_snp_filter_group_original {
  my $self = shift;
  my @entry_objs = @_;

  my $check_obj1  = shift @entry_objs;
  my $hidden_obj      = pop @entry_objs;
  my $check_obj2  = pop @entry_objs;

  #my $tmpl = ( $self->get_row('entry_filter2').
	#       "%s".
	 #      $self->get_row('entry_select').
	  #     $self->get_row('entry_filter2'));#.
#	       $self->get_row('entry_filter2'));

  #my $check1 = $self->_gen_element( 'CHECKBOX', $check_obj1 );
  #my $check2 = $self->_gen_element( 'CHECKBOX', $check_obj2 );
  #my $hidden = $self->_gen_base_form
   # (
    # -type => 'HIDDEN2',
     #-name => $hidden_obj->get_cgi_name,
     #-#value=> $hidden_obj->get_value,
     #get_extra( $hidden_obj )
    #);
  #return sprintf
   # ( $tmpl, 
    #  $check1, 
     # $check_obj1->get_label(), 
      #$self->_gen_specified_group( 'RADIO', @entry_objs ),
      #$check2,
      #$check_obj2->get_label(),
      #'&nbsp;',$hidden,
      #);
  return( $self->gen_check_with_label($check_obj1).
          $self->_gen_specified_group( 'RADIO',@entry_objs).
          $self->gen_check_with_label($check_obj2).
          $self->gen_hidden($hidden_obj));
}
sub gen_snp_filter_group_new {
  my $self = shift;
  my @entry_objs = @_;

  my $check_obj1  = shift @entry_objs;
  #my $hidden_obj      = pop @entry_objs;
  #my $check_obj2  = pop @entry_objs;

  #my $tmpl = ( $self->get_row('entry_filter2').
	#       "%s".
	 #      $self->get_row('entry_select').
	  #     $self->get_row('entry_filter2'));#.
#	       $self->get_row('entry_filter2'));

  #my $check1 = $self->_gen_element( 'CHECKBOX', $check_obj1 );
  #my $check2 = $self->_gen_element( 'CHECKBOX', $check_obj2 );
  #my $hidden = $self->_gen_base_form
   # (
    # -type => 'HIDDEN2',
     #-name => $hidden_obj->get_cgi_name,
     #-#value=> $hidden_obj->get_value,
     #get_extra( $hidden_obj )
    #);
  #return sprintf
   # ( $tmpl, 
    #  $check1, 
     # $check_obj1->get_label(), 
      #$self->_gen_specified_group( 'RADIO', @entry_objs ),
      #$check2,
      #$check_obj2->get_label(),
      #'&nbsp;',$hidden,
      #);
  return( $self->gen_check_with_label($check_obj1).
          $self->_gen_specified_group( 'RADIO',@entry_objs));#.
          #$self->gen_check_with_label($check_obj2).
          #$self->gen_hidden($hidden_obj));
}
#----------------------------------------------------------------------
# Special group for handling sequence-type selection
sub gen_seq_type_group{
  my $self = shift;
  my @entry_objs = @_;

  my $radio1_obj = shift @entry_objs;
  my $radio2_obj = shift @entry_objs;
#  my $radio3_obj = shift @entry_objs;
  my $image_obj  = shift @entry_objs;
  my $entry_3bp = pop @entry_objs;
  my $entry_5bp = pop @entry_objs;

  my $tmpl = ( $self->get_row('entry_filter2').
	       $self->get_row('entry_filter2').
#	       $self->get_row('entry_filter2').
	       $self->get_row('entry_info'   ).
	       "%s".
	       $self->get_row('entry_select') );

  my $radio1 = $self->_gen_radio( $radio1_obj );

  my $radio2 = $self->_gen_radio( $radio2_obj );

#  my $radio3 = $self->_gen_radio( $radio3_obj );

  my $src  = EnsEMBL::Web::BlastView::Panel::IMG_ROOT_ROVER.'/'.$image_obj->get_src;
  my $name =  $image_obj->get_cgi_name;
  my $image = "<IMG src=\"$src\" name=\"$name\" border=\"0\" />";

  my @labels;
  my @text_box;
  foreach( $entry_5bp, $entry_3bp ){
    push( @text_box, '&nbsp;'    );
    push( @labels, $_->get_label );
    push( @text_box, 
	  ( $_->get_label.
	    $self->_gen_text($_) ) );
  }
  
  return sprintf
    ( $tmpl, 
      $radio1, 
      $radio1_obj->get_label(), 
      $radio2, 
      $radio2_obj->get_label(), 
#      $radio3, 
#      $radio3_obj->get_label(), 
      $image,
      $self->_gen_specified_group( 'RADIO', @entry_objs ),
      @text_box ); 
}

#----------------------------------------------------------------------
# Radio group with a text box at the end
sub gen_sequence_type_group{
  my $self = shift;
  my @entry_objs = @_;

  # Remove the radios/textboxes from the entry_objs array
  my @radio;
  my @text;
  ( $radio[0],$text[0],$radio[1],$text[1] ) =  splice( @entry_objs, -4, 4 );
  
  # Generate the radio-group HTML
  my $check_group_html = $self->_gen_specified_group( 'RADIO', @entry_objs );
  
  # Generate the radio/textbox html
  my $tmpl = $self->get_row('entry_filter');
  my @flanks;
  for( 0, 1 ){
    my $i = $_;
    
    my $text_html = $self->_gen_text( $text[$i] );
  
    my $radio_html = $self->_gen_radio( $radio[$i] );

    push @flanks, sprintf( $tmpl, 
			   $radio_html,  
			   $radio[$i]->get_label,
			   $text_html);
  }

  return $check_group_html.join( '', @flanks );
  
}

#----------------------------------------------------------------------
# Chromosome select with start+end filter
sub gen_chrom_start_end_filter{
  my $self = shift;
  my $check_with_label  = $self->gen_check_with_label( shift );
  my $label_with_select = $self->gen_label_with_select( shift );
  my $select_with_text  = $self->gen_select_with_text_and_select( @_ );
  return $check_with_label.$label_with_select.$select_with_text;
}

#----------------------------------------------------------------------
# Chromosome select with start+end filter
sub gen_proteome_region_filter{
  my $self = shift;
  #my $check_with_label  = $self->gen_check_with_label( shift );
  my $check =  sprintf( $self->get_row('entry_filter2'),$self->_gen_element( 'CHECKBOX',shift ),'&nbsp');
  my $label_with_select1 = $self->gen_label_with_select( shift );
  my $hidden = $self->gen_hidden(shift);
  my $label_with_text1 = $self->gen_label_with_text( shift );
  my $label_with_text2 = $self->gen_label_with_text( shift );
  return $check.$label_with_select1.$hidden.$label_with_text1.$label_with_text2;
}
#----------------------------------------------------------------------
# Chromosome select with start+end filter for fugu - temp fix
sub gen_chrom_start_end_filter_lots{
  my $self = shift;
  my $check_with_label  = $self->gen_check_with_label( shift );
  my $label_with_text = $self->gen_label_with_text( shift );
  my $select_with_text  = $self->gen_select_with_text( @_ );
  return $check_with_label.$label_with_text.$select_with_text;
}

#----------------------------------------------------------------------
# Flanking regions for snps
sub gen_sequence_type_snp{
  my $self = shift;
  my @entry_objs = @_;

  my $hidden = $self->_gen_base_form
    (
     -type => 'HIDDEN',
     -name => $entry_objs[0]->get_cgi_name,
     -value=> $entry_objs[0]->get_value,
     get_extra( $entry_objs[0] )
    );

  my $flank5 = $self->_gen_text( $entry_objs[1] );

  my $flank3 = $self->_gen_text( $entry_objs[2] );

  my $tmpl = $self->get_row('entry_button');

  return sprintf( $tmpl,
		  $entry_objs[1]->get_label.$flank5.$hidden,
		  $entry_objs[2]->get_label.$flank3 );

}

#----------------------------------------------------------------------
#
sub gen_radio_with_label{
  my $self       = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter2');
  
  my $hidden = $self->_gen_radio( $entry_objs[0] );

  return sprintf( $tmpl, $hidden, $entry_objs[0]->get_label );

}

#----------------------------------------------------------------------
#

sub gen_label{
  my $self       = shift;
  my @entry_objs = @_;

  my $tmpl = ( $self->get_row('entry_info') ); 

  return sprintf( $tmpl, 
		  $entry_objs[0]->get_label(), );
}

#----------------------------------------------------------------------
#
sub gen_label_with_text{
  my $self  = shift;
  my $entry = shift;
  my $tmpl = ( $self->get_row('entry_filter3') );
  my $text = $self->_gen_text( $entry );
  return sprintf( $tmpl, 
		  $entry->get_label(),
		  $text);

}

#----------------------------------------------------------------------
#
sub gen_label_with_radiogroup{
  my $self  = shift;
  my @entry_objs = @_;
  my $label = shift @entry_objs;

  my $tmpl = ( $self->get_row('entry_center').
	       $self->get_row('entry_select') );
  my $tmpl = $self->get_row('entry_center');
  return sprintf( $tmpl, 
		  $label->get_label()).
		  $self->_gen_specified_group('RADIO', @entry_objs);
}

#----------------------------------------------------------------------
#
sub gen_label_with_textarea{
  my $self  = shift;
  my $entry = shift || croak( "Need a FormEntry" );
  
  my $tmpl = ( $self->get_row('entry_info'). 
	       $self->get_row('entry_filter2') );

  my $text = $self->_gen_textarea( $entry );

  return sprintf( $tmpl, 
		  $entry->get_label(),
		  '&nbsp;', $text);

}

#----------------------------------------------------------------------
#
sub gen_label_and_file{
  my $self       = shift;
  my @entry_objs = @_;

  my $tmpl = ( $self->get_row('entry_info'). 
	       $self->get_row('entry_filter2') );

  my $text = $self->_gen_base_form( -type => 'FILE',
				    -name => $entry_objs[0]->get_cgi_name,
				    get_extra( $entry_objs[0] ) );

  return sprintf( $tmpl, 
		  $entry_objs[0]->get_label(),
		  '&nbsp;',$text);

}

#----------------------------------------------------------------------
#
sub gen_label_with_file{
  my $self       = shift;
  my @entry_objs = @_;

  my $tmpl = ( $self->get_row('entry_filter') );

  my $text = $self->_gen_base_form( -type => 'FILE',
				    -name => $entry_objs[0]->get_cgi_name,
				    get_extra( $entry_objs[0] ) );
  my $hidden;
  if( $entry_objs[1] ){
    $hidden = $self->_gen_base_form( -type => 'HIDDEN2',
				     -name => $entry_objs[1]->get_cgi_name,
				     get_extra( $entry_objs[1] ) );
  }

  return sprintf( $tmpl, 
		  '&nbsp;',
		  $entry_objs[0]->get_label() || '&nbsp',
		  $text.$hidden);

}

#----------------------------------------------------------------------
#
sub gen_label_with_text_and_submit{
  my $self       = shift;
  my @entry_objs = @_;

  my $tmpl = ( $self->get_row('entry_info'). 
	       $self->get_row('entry_filter2') );

  my $text = $self->_gen_text( $entry_objs[0] );

  my $submit = "<INPUT type='submit' name='%s', value='%s' />";
  $submit = sprintf( $submit, 
		     $entry_objs[1]->get_cgi_name, 
		     $entry_objs[1]->get_value );
  return sprintf( $tmpl, 
		  $entry_objs[0]->get_label(),
		  '&nbsp;',$text.$submit);

}

#----------------------------------------------------------------------
#
sub gen_text_and_submit{
  my $self = shift;
  my @entry_objs = @_;
  my $tmpl = $self->get_row('entry_filter3');
  my $text = $self->_gen_text( $entry_objs[0] );
  
  my $submit = "<INPUT type='submit' name='%s', value='%s' />";
  $submit = sprintf( $submit, 
		     $entry_objs[1]->get_cgi_name, 
		     $entry_objs[1]->get_value );
  return sprintf( $tmpl,$text,$submit);
}

#----------------------------------------------------------------------
sub gen_textarea_file_text_and_radio{
  my $self = shift;
  my @entries = @_;

#  # Shift the radio entries off the list
#  my $radio_name = $entries[0]->get_cgi_name();#
#  my @radios = ();
#  while( $entries[0] ){
#    if( $entries[0]->get_cgi_name() ne $radio_name ){ last }
#    push( @radios, shift @entries );
#  }

  my $html = '';

  # textarea
  $html .=   $self->gen_label_with_textarea( shift @entries );
  $html .=   $self->get_row('entry_padding');

  # file
  $html .=   $self->gen_label_and_file    ( shift @entries );
  $html .=   $self->get_row('entry_padding');

  # Textbox
  my $text   = shift @entries;
  my $submit = shift @entries;	
  if( $text->get_label ){
    $html .=   $self->gen_label_with_text_and_submit( $text, 
						      $submit );
    $html .=   $self->get_row('entry_padding');
  }

  # Radios
  $html .= $self->gen_radio_group( @entries  );
  $html .=   $self->get_row('entry_padding');
  
  return $html;
}

#----------------------------------------------------------------------
sub gen_textarea_file_text_text_and_radio{
  my $self = shift;
  my @entries = @_;

#  # Shift the radio entries off the list
#  my $radio_name = $entries[0]->get_cgi_name();#
#  my @radios = ();
#  while( $entries[0] ){
#    if( $entries[0]->get_cgi_name() ne $radio_name ){ last }
#    push( @radios, shift @entries );
#  }

  my $html = '';

  # textarea
  $html .=   $self->gen_label_with_textarea( shift @entries );
  $html .=   $self->get_row('entry_padding');

  # file
  $html .=   $self->gen_label_and_file    ( shift @entries );
  $html .=   $self->get_row('entry_padding');

  # Textbox1
  my $text   = shift @entries;
  my $submit = shift @entries;	
  if( $text->get_label ){
    $html .=   $self->gen_label_with_text_and_submit( $text, 
						      $submit );
    $html .=   $self->get_row('entry_padding');
  }

  # Textbox2
  my $text2   = shift @entries;
  my $submit2 = shift @entries;	
  if( $text2->get_label ){
    $html .=   $self->gen_label_with_text_and_submit( $text2, 
						      $submit2 );
    $html .=   $self->get_row('entry_padding');
  }

  # Radios
  $html .= $self->gen_radio_group( @entries  );
  $html .=   $self->get_row('entry_padding');
  
  return $html;
}

#----------------------------------------------------------------------
# Either radio_with_select, or check_with_select
sub _gen_type_with_select{
  my $self    = shift;
  my $type    = shift;
  my @entries = @_;

  my $tmpl = $self->get_row('entry_filter');

  my $html = '';
  for( my $i=0; $i<@entries; $i+=2 ){
    my $j = $i+1;
    my $radio1 = $self->_gen_base_form( -type => $type,
					-name => $entries[$i]->get_cgi_name,
					-value=> $entries[$i]->get_value,
					get_extra( $entries[$i] ) );
  
    my $sel = $self->_gen_select( $entries[$j] );
    
    $html .= sprintf( $tmpl,
		      $radio1, $entries[$i]->get_label , $sel );
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_radio_with_select{
  my $self     = shift;
  return $self->_gen_type_with_select('RADIO',@_);
}

#----------------------------------------------------------------------
#
sub gen_check_with_select{
  my $self     = shift;
  return $self->_gen_type_with_select('CHECKBOX',@_);
}

#----------------------------------------------------------------------
#
sub gen_select_with_buttons{
  my $self = shift;
  my @entries = @_;
  my $tmpl = $self->get_row('entry_filter4');
  my $slct = $self->_gen_element('SELECT', shift @entries );
  my $buttons;
  foreach my $obj( @entries ){
    $buttons .= $self->_gen_element( $obj->get_type, $obj );
  }
  return sprintf( $tmpl, '&nbsp;', $slct, $buttons );
}
#----------------------------------------------------------------------
#
sub gen_radio_with_two_buttons{
  my $self = shift;
  my $tmpl = $self->get_row('entry_select');
  my $html;
  # Groups of 3.
  my $x = 0;
  my @row;
  while( my $obj = shift @_ ){
    if( $x == 0 ){
      push @row, $self->_gen_radio( $obj );
      push @row, $obj->get_label;
    }
    else{
      if( $obj->get_value ){
	push @row, $self->_gen_base_form( -type => 'IMAGE2',
					  -name => $obj->get_cgi_name,
					  -value=> $obj->get_value,
					  get_extra( $obj ) );
      }
      #else{
#	$row[@row] .= $self->_gen_element( 'HIDDEN2', $obj );
#      }
    }
    $x++;
    if( $x == 3 ){ 
      $html .= sprintf( $tmpl, $row[0], $row[1], '&nbsp;', $row[2].$row[3] );
      $x=0; 
      @row = ();
    }
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_check_with_text{
  my $self     = shift;
  my @entry_objs = @_;
  return sprintf( $self->get_row('entry_filter'),
		  $self->_gen_element( 'CHECKBOX', $entry_objs[0] ),
		  $entry_objs[0]->get_label, 
		  $self->_gen_text( $entry_objs[1] ));
}

#----------------------------------------------------------------------
#
sub gen_check_with_texts{
  my $self     = shift;
  my $check = shift;
  my @entry_objs = @_;
  my $text_html;
  foreach (@entry_objs){
      $text_html .= sprintf($self->get_row('entry_filter'),'&nbsp;',$_->get_label,$self->_gen_text( $_ ),'&nbsp;');
  }
  return sprintf( $self->get_row('entry_filter'),
		  $self->_gen_element( 'CHECKBOX', $check ),
		  $check->get_label,'&nbsp;').
		  $text_html;
}

#----------------------------------------------------------------------
#
sub gen_check_with_text_and_hidden{
  my $self     = shift;
  my @entry_objs = @_;
  my $hidden = $self->gen_hidden(pop @entry_objs);
  return sprintf( $self->get_row('entry_filter'),
		  $self->_gen_element( 'CHECKBOX', $entry_objs[0] ),
		  $entry_objs[0]->get_label, 
		  $self->_gen_text( $entry_objs[1] ) ).$hidden;
}
#----------------------------------------------------------------------
#
sub gen_check_with_text_and_text{
  my $self     = shift;
  my @entry_objs = @_;

  return sprintf( $self->get_row('entry_filter'),
		  $self->_gen_element( 'CHECKBOX', $entry_objs[0] ),
		  $entry_objs[0]->get_label, 
		  $self->_gen_text( $entry_objs[1] ).'AND'.$self->_gen_text( $entry_objs[2] ) );
  #return sprintf( $self->get_row('entry_filter'),
	#	  $self->_gen_element( 'CHECKBOX', $entry_objs[0] ),
		#  $entry_objs[0]->get_label, 
		 # $self->_gen_text( $entry_objs[1] ) );
  
}
#----------------------------------------------------------------------
#
sub gen_check_with_textarea{
  my $self       = shift;
  my @entry_objs = @_;
  return sprintf( $self->get_row('entry_filter'),
		  $self->_gen_element( 'CHECKBOX', $entry_objs[0] ),
		  $entry_objs[0]->get_label, 
		  $self->_gen_textarea( $entry_objs[1] ) );
}

#----------------------------------------------------------------------
#
sub gen_check_with_select_and_text{
  my $self       = shift;
  my $check_with_label   = $self->gen_check_with_label( shift );
  my $label_with_select1 = $self->gen_label_with_select( shift );
  my $text = $self->gen_label_with_text( shift );

  
  return $check_with_label.$label_with_select1.$text;

}
#----------------------------------------------------------------------
#
sub gen_check_with_select_and_textarea{
  my $self       = shift;
  my @entry_objs = @_;

  my $tmpl = ( $self->get_row('entry_filter') );

  my $check = $self->_gen_element( 'CHECKBOX', $entry_objs[0] );

  my $select = $self->_gen_select( $entry_objs[1] );
				      
  my $label = $entry_objs[1]->get_label || '';
  $label &&= $label.'<br>';

  my $text = $self->_gen_textarea( $entry_objs[2] );

  return sprintf( $tmpl,
		  $check, $label.$select, $text );


}

#----------------------------------------------------------------------
#
sub gen_select_and_select{
  my $self       = shift;
  my $check_with_label   = $self->gen_check_with_label( shift );
  my $label_with_select1 = $self->gen_label_with_select( shift );
  my $label_with_select2 = $self->gen_label_with_select( shift );

  my $hidden; # Used for dynamic select options (JS)
  if( my $entry = shift ){
    $hidden = $self->_gen_base_form( -type => 'HIDDEN2',
				     -name => $entry->get_cgi_name,
				     get_extra( $entry ));
  }
  return $check_with_label.$label_with_select1.$label_with_select2.$hidden;
}
#----------------------------------------------------------------------
#
sub gen_select_with_text{
  my $self     = shift;
  my @entries  = @_;

  my $tmpl = $self->get_row('entry_filter3');
  
  my $html = '';
  for( my $i=0; $i<@entries; $i+=2 ){
    my $j = $i+1;

    my $slct = $self->_gen_select( $entries[$i] );

    my $text = $self->_gen_text( $entries[$j] );
    $html .= sprintf( $tmpl, $entries[$i]->get_label.$slct, $text );
  }
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_label_with_select{
  my $self  = shift;
  my $entry = shift;
  my $tmpl = $self->get_row('entry_filter3');
  my $slt1 = $self->_gen_select( $entry ); 
  return sprintf( $tmpl, $entry->get_label,$slt1);

}

#----------------------------------------------------------------------
#
sub gen_start_select{
  my $self  = shift;
  my $entry = shift;
  my $tmpl = $self->get_row('entry_filter12');
  my $slt1 = $self->_gen_select( $entry ); 
  return sprintf( $tmpl, $entry->get_label.$slt1,'&nbsp;' );

}
#----------------------------------------------------------------------
#
sub gen_select_with_text_and_select{
  my $self     = shift;
  my @entries  = @_;

  my $tmpl = $self->get_row('entry_filter3');
  
  my $html = '';
  for( my $i=0; $i<@entries; $i+=4 ){
    my $j = $i+1;
    my $k = $i+2;
    my $l = $i+3;

    my $slt1 = $self->_gen_select( $entries[$i] );

    my $text = $self->_gen_text( $entries[$j] );

    my $slt2 = $self->_gen_select( $entries[$k] );

    my $hidn = $self->_gen_base_form( -type => 'HIDDEN2',
				      -name => $entries[$l]->get_cgi_name,
				      get_extra( $entries[$l] ) );

    $html .= sprintf( $tmpl, $entries[$i]->get_label.$slt1, $text.$slt2.$hidn );
  }
  return $html;
}
#----------------------------------------------------------------------
#
sub gen_check_with_select_textarea_and_file{
  my $self       = shift;
  my @row1_objs = @_[0..2];
  my @row2_objs = @_[3];
  
  my $hidden1 = @_[4];
  return( #$self->gen_label($label).
	 $self->gen_check_with_select_and_textarea(@row1_objs).
	  $self->gen_label_with_file(@row2_objs)
	  #.$self->gen_hidden($hidden1)
          );
}
#----------------------------------------------------------------------
#
sub gen_check_with_select_textarea_and_file_and_check{
  my $self       = shift;
  #my $label = @_[0];
  my @row1_objs = @_[0..2];
  my @row2_objs = @_[3];
  #my @row3_objs = @_[5];
  my $check1 = @_[4];
  my $hidden1 = @_[5];
  #my $hidden2 = @_[6];
  return( #$self->gen_label($label).
	 $self->gen_check_with_select_and_textarea(@row1_objs).
	  $self->gen_label_with_file(@row2_objs). 
	  $self->gen_check_with_label($check1).
	  #$self->gen_narrow_broad_radios(@row3_objs).
	  $self->gen_hidden($hidden1));
	  #$self->gen_hidden($hidden2));

}
#----------------------------------------------------------------------
#
sub gen_check_with_select_textarea_and_file_snp{
  my $self       = shift;
  my @row1_objs = @_[0..2];
  my @row2_objs = @_[3];
  #my @row3_objs = @_[4];
  my $hidden1 = @_[4];
  #my $hidden2 = @_[6];
  return( $self->gen_check_with_select_and_textarea(@row1_objs).
	  $self->gen_label_with_file(@row2_objs). 
	  #$self->gen_narrow_broad_radios(@row3_objs).
	  $self->gen_hidden($hidden1));
	  #$self->gen_hidden($hidden2));

}
#----------------------------------------------------------------------
#
sub gen_check_with_two_text{
  my $self     = shift;
  my @entry_objs = @_;
  
  my $tmpl = ( $self->get_row('entry_filter2').
	       $self->get_row('entry_filter3').
	       $self->get_row('entry_filter3') );

  my $check = $self->_gen_element( 'CHECKBOX', $entry_objs[0] );

  my $text1 = $self->_gen_text( $entry_objs[1] );

  my $text2 = $self->_gen_text( $entry_objs[2] );

  return sprintf( $tmpl,
		  $check, $entry_objs[0]->get_label, 
		  $entry_objs[1]->get_label, $text1,
		  $entry_objs[2]->get_label, $text2 );
}
#----------------------------------------------------------------------
# TODO: share code with _gen_check_with_two_text
sub gen_radio_with_two_text{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = ( $self->get_row('entry_filter2').
	       $self->get_row('entry_filter3').
	       $self->get_row('entry_filter3') );

  my $check = $self->_gen_radio( $entry_objs[0] );
  my $text1 = $self->_gen_text(  $entry_objs[1] );
  my $text2 = $self->_gen_text(  $entry_objs[2] );

  return sprintf( $tmpl,
		  $check, $entry_objs[0]->get_label, 
		  $entry_objs[1]->get_label, $text1,
		  $entry_objs[2]->get_label, $text2 );
}

#----------------------------------------------------------------------
#
sub gen_text_box_with_info{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = join( '',
		   $self->get_row('entry_filter5'),
		   $self->get_row('entry_info') );

  my $text  = $self->_gen_base_form( -type => 'TEXT',
				     -name => $entry_objs[0]->get_cgi_name,
				     get_extra( $entry_objs[0] ) );

  return sprintf( $tmpl,
		  $entry_objs[0]->get_label, $text,
		  $entry_objs[1]->get_label);
}

#----------------------------------------------------------------------
#
sub gen_radio_with_select_and_range{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = join( '',
		   $self->get_row('entry_filter'),
		   $self->get_row('entry_filter3'),
		   $self->get_row('entry_filter3') );

  my $check =  $self->_gen_radio( $entry_objs[0] );

  my $select = $self->_gen_select( $entry_objs[1] );

  my $range1 = $self->_gen_base_form( -type => 'TEXT',
				      -name => $entry_objs[2]->get_cgi_name,
				      get_extra( $entry_objs[2] ) );

  my $range2 = $self->_gen_base_form( -type => 'TEXT',
				      -name => $entry_objs[3]->get_cgi_name,
				      get_extra( $entry_objs[3] ));

  return sprintf( $tmpl,
		  $check, $entry_objs[0]->get_label, $select,
		  $entry_objs[2]->get_label, $range1,
		  $entry_objs[3]->get_label, $range2 );
}

#----------------------------------------------------------------------
#
sub gen_radio_with_select_and_range_select{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = join( '',
		   $self->get_row('entry_filter'),
		   $self->get_row('entry_filter3'),
		   $self->get_row('entry_filter3') );

  my $check =  $self->_gen_radio( $entry_objs[0] );

  my $select = $self->_gen_select( $entry_objs[1] );

  my $range1 = $self->_gen_select( $entry_objs[2] );

  my $range2 = $self->_gen_select( $entry_objs[3] );

  return sprintf( $tmpl,
		  $check, $entry_objs[0]->get_label, $select,
		  $entry_objs[2]->get_label, $range1,
		  $entry_objs[3]->get_label, $range2 );
}

#----------------------------------------------------------------------
#
sub gen_check_with_radio{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter4');

  my $check =  $self->_gen_element( 'CHECKBOX', $entry_objs[0] );

  my $radio1 = $self->_gen_radio( $entry_objs[1] );

  my $radio2 = $self->_gen_radio( $entry_objs[2] );

  return sprintf( $tmpl, 
		  $check, $entry_objs[0]->get_label,
		  $radio1, $entry_objs[1]->get_label,
		  $radio2, $entry_objs[2]->get_label )
}
#----------------------------------------------------------------------
#
sub gen_narrow_broad_radios{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter2');

  my $radio1 = $self->_gen_element( 'CHECKBOX', $entry_objs[0] );
  my $html = sprintf($tmpl, $radio1, $entry_objs[0]->get_label);
  return $html;
}

#----------------------------------------------------------------------
#
sub gen_check_with_radio_group{
  my $self     = shift;
  my @entry_objs = @_;

  my @check_objs;
  # Is the first obj a label?
  if( $entry_objs[0]->get_label && 
    ! $entry_objs[0]->get_value ){
    # Take first 2 objs for checkbox
    @check_objs = ( shift( @entry_objs ), shift( @entry_objs ) );
  }
  else{  
    # Take first 1 objs for checkbox
    @check_objs = ( shift( @entry_objs ) );
  }

  my $check = $self->_gen_specified_group( 'CHECKBOX', @check_objs );
  my $radio = $self->_gen_specified_group( 'RADIO',    @entry_objs );
  return $check.$radio;
}

#----------------------------------------------------------------------
#
sub gen_radio_group_with_checkbox_group{
  my $self     = shift;
  my @entry_objs = @_;

  my $radio_name = $entry_objs[0]->get_cgi_name();
  my @radio_objs = ();
  while( $entry_objs[0] ){
    if( $entry_objs[0]->get_cgi_name() ne $radio_name ){ last }
    push( @radio_objs, shift @entry_objs );
  }
  my $radio = $self->_gen_specified_group( 'RADIO',    @radio_objs );
  my $check = $self->_gen_specified_group( 'CHECKBOX', @entry_objs );
  return $radio.$check;
}

#----------------------------------------------------------------------
#
sub gen_check_with_select_and_radio{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter4');

  my $check =  $self->_gen_element( 'CHECKBOX',$entry_objs[0] );

  my $select = $self->_gen_select($entry_objs[1]);
  if( my $l = $entry_objs[1]->get_label ){ $select = "$l $select" }

  my $radio1 = $self->_gen_radio($entry_objs[2]);

  my $radio2 = $self->_gen_radio($entry_objs[3]);

  return sprintf( $tmpl, 
		  $check, $select,
		  $radio1, $entry_objs[2]->get_label,
		  $radio2, $entry_objs[3]->get_label )

}
#----------------------------------------------------------------------
#
sub gen_proteome_species{
  my $self     = shift;
  my @entry_objs = @_;
  my $text = pop @entry_objs;
  my $hidden_obj = pop @entry_objs;
  my $hidden =  $self->gen_hidden($hidden_obj);
  my $hidden_obj2 = pop @entry_objs;
  my $hidden2 =  $self->gen_hidden($hidden_obj2);
  my $check = $self->_gen_element('CHECKBOX',$entry_objs[0]);
  my $html1 = sprintf( $self->get_row('entry_filter2'), $check,  $entry_objs[0]->get_label);
  
  my $radio_group = $self->gen_radio_group(@entry_objs[1..3]);
  
  my $select = $self->_gen_select($entry_objs[4]);
  my $html2 = sprintf( $self->get_row('entry_filter'), '&nbsp;', '&nbsp;',$select);
  
  my $label_with_textarea = $self->gen_label_with_textarea($text);

  return $html1.$radio_group.$html2.$hidden2.$hidden.$label_with_textarea;

}
#----------------------------------------------------------------------
#
sub gen_check_with_label_and_select{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter');

  my $check =  $self->_gen_element( 'CHECKBOX',$entry_objs[0] );
  #my $label = $entry_objs[0]->get_label;

  my $select = $self->_gen_select($entry_objs[1]);

  #my $radio1 = $self->_gen_radio($entry_objs[2]);

  #my $radio2 = $self->_gen_radio($entry_objs[3]);

  return sprintf( $tmpl, 
		  $check, $entry_objs[0]->get_label, $select)
		  #$radio1, $entry_objs[2]->get_label,
		  #$radio2, $entry_objs[3]->get_label )

}
#----------------------------------------------------------------------
#
sub gen_gene_ontology{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter'). $self->get_row('entry_filter'). $self->get_row('entry_filter'). $self->get_row('entry_filter');

  my $check =  $self->_gen_element( 'CHECKBOX',$entry_objs[0] );
  #my $label = $entry_objs[0]->get_label;

  my $select = $self->_gen_select($entry_objs[1]);

  my $text1 = $self->_gen_text($entry_objs[2]);
  my $butt1 = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $entry_objs[3]->get_cgi_name,
				    -value=> $entry_objs[3]->get_value,
				    get_extra( $entry_objs[3] ) );
  my $text2 = $self->_gen_text($entry_objs[4]);
  my $butt2 = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $entry_objs[5]->get_cgi_name,
				    -value=> $entry_objs[5]->get_value,
				    get_extra( $entry_objs[5] ) );
  my $text3 = $self->_gen_text($entry_objs[6]);
  my $butt3 = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $entry_objs[7]->get_cgi_name,
				    -value=> $entry_objs[7]->get_value,
				    get_extra( $entry_objs[7] ) );
  my $extra_html;
  $extra_html = $self->gen_hidden($entry_objs[8]) if ($entry_objs[8]);
  $extra_html .= $self->gen_hidden($entry_objs[9]) if ($entry_objs[8]) ;
  $extra_html .= $self->gen_hidden($entry_objs[10]) if ($entry_objs[8]);

  my $html =  sprintf( $tmpl, 
		  $check, $entry_objs[0]->get_label, $select,
		  '&nbsp;',$entry_objs[2]->get_label, $text1.$butt1,
		  '&nbsp;',$entry_objs[4]->get_label, $text2.$butt2,
                  '&nbsp;',$entry_objs[6]->get_label, $text3.$butt3);
  
  return $html.$extra_html;  
}

#----------------------------------------------------------------------
#
sub gen_proteome_gene_ontology{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl1 = $self->get_row('entry_filter');#."%s";#.$self->get_row('entry_filter'). $self->get_row('entry_filter'). $self->get_row('entry_filter');

  my $check =  $self->_gen_element( 'CHECKBOX',$entry_objs[0] );
  my @radios = @entry_objs[1..5];
  my $radio_group = $self->_gen_specified_group('RADIO',@radios);
  my $text1 = $self->_gen_text($entry_objs[6]);
  my $butt1 = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $entry_objs[7]->get_cgi_name,
				    -value=> $entry_objs[7]->get_value,
				    get_extra( $entry_objs[7] ) );
  my $text2 = $self->_gen_text($entry_objs[8]);
  my $butt2 = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $entry_objs[9]->get_cgi_name,
				    -value=> $entry_objs[9]->get_value,
				    get_extra( $entry_objs[9] ) );
  my $text3 = $self->_gen_text($entry_objs[10]);
  my $butt3 = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $entry_objs[11]->get_cgi_name,
				    -value=> $entry_objs[11]->get_value,
				    get_extra( $entry_objs[11] ) );
  #my $extra_html;
  my $extra_html = $self->gen_hidden($entry_objs[12]);
  $extra_html   .= $self->gen_hidden($entry_objs[13]);
  $extra_html   .= $self->gen_hidden($entry_objs[14]);
  
  my $select1 = $self->_gen_select($entry_objs[15]);
  my $select2 = $self->_gen_select($entry_objs[16]);
  my $select3 = $self->_gen_select($entry_objs[17]);
  
  my $label1 = $self->gen_label($entry_objs[18]);
  my $label2 = $self->gen_label($entry_objs[19]);
  my $label3 = $self->gen_label($entry_objs[20]);

  my $html =  sprintf( $tmpl1, 
		  $check, $entry_objs[0]->get_label,'&nbsp;').
		   $radio_group.
		   $self->get_row('entry_padding').
		   $label1.
		   $self->get_row('entry_rule').
		   sprintf ( $self->get_row('entry_filter'),'&nbsp;',$butt1.$entry_objs[15]->get_label,$select1, ).
		   sprintf ( $self->get_row('entry_filter'),'&nbsp;',$text1,$entry_objs[6]->get_label).
		   $self->get_row('entry_padding').
		   $label2.
		   $self->get_row('entry_rule').
		   sprintf ( $self->get_row('entry_filter'),'&nbsp;',$butt2.$entry_objs[16]->get_label,$select2, ).
		   sprintf ( $self->get_row('entry_filter'),'&nbsp;',$text2,$entry_objs[8]->get_label).
		   $self->get_row('entry_padding').
		   $label3.
		   $self->get_row('entry_rule').
		   sprintf ( $self->get_row('entry_filter'),'&nbsp;',$butt3.$entry_objs[17]->get_label,$select3, ).
		   sprintf ( $self->get_row('entry_filter'),'&nbsp;',$text3,$entry_objs[10]->get_label);
		  
  return $html.$extra_html;  
}

#----------------------------------------------------------------------
#
sub gen_check_with_label_text_and_select{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_filter11');

  my $check =  $self->_gen_element( 'CHECKBOX',$entry_objs[0] );
  #my $label = $entry_objs[0]->get_label;
  my $text   = $self->_gen_text($entry_objs[1]);
  my $select = $self->_gen_select($entry_objs[2]);

  #my $radio1 = $self->_gen_radio($entry_objs[2]);

  #my $radio2 = $self->_gen_radio($entry_objs[3]);

  return sprintf( $tmpl, 
		  $check, $entry_objs[0]->get_label, $text, $select)
		  #$radio1, $entry_objs[2]->get_label,
		  #$radio2, $entry_objs[3]->get_label )

}
#----------------------------------------------------------------------
sub gen_ontology_filter{
  my $self = shift;
  my @entry_objs = @_;

  my $check_obj  = shift @entry_objs;
  my $hidden_obj = shift @entry_objs;
  my $radio1_obj = shift @entry_objs;
  my $radio2_obj = shift @entry_objs;

#  my $html = $self->gen_check_with_label( $check_obj, $hidden_obj );

  my $html = $self->gen_check_with_radio( $check_obj, 
					  $radio1_obj, 
					  $radio2_obj );

  $html .= $self->gen_hidden( $hidden_obj );

  $html .= $self->get_row('entry_padding');

  while( @entry_objs ){
    # Take two entry_objs at a time off the top of the array
    $html .= $self->gen_label_with_text_and_button( shift @entry_objs,
						    shift @entry_objs );
  }
  return $html;
}
#----------------------------------------------------------------------

sub gen_expression_ontology{
  my $self = shift;
  my @entry_objs = @_;

  my $check_obj  = shift @entry_objs;
  #my $hidden_obj = shift @entry_objs;
  my $select_obj = shift @entry_objs;
  #my $radio2_obj = shift @entry_objs;



  my $html = $self->gen_check_with_select( $check_obj, 
					  $select_obj);

  #$html .= $self->gen_hidden( $hidden_obj );

  $html .= $self->get_row('entry_padding');

  while( @entry_objs ){
    # Take two entry_objs at a time off the top of the array
    $html .= $self->gen_label_with_text_and_button( shift @entry_objs,
						    shift @entry_objs );
  }
  return $html;
}

#----------------------------------------------------------------------
sub gen_proteome_sequence_atts{
  my $self = shift;
  my @entry_objs = @_;
  #my $check_obj1 = shift @entry_objs;
  #my $check_obj2 = shift @entry_objs;
  #return( $self->gen_check_with_label($check_obj1).
  #        $self->gen_check_with_label($check_obj2));
  return $self->gen_radio_group(@entry_objs);
}

sub gen_hidden{
  my $self = shift;
  my $hidden_obj = shift;

  my $hidden = $self->_gen_base_form
    ( -type => 'HIDDEN2',
      -name => $hidden_obj->get_cgi_name,
      -value=> $hidden_obj->get_value,
      get_extra( $hidden_obj ) );

  return $hidden;
}

#----------------------------------------------------------------------
sub gen_check_with_label{
  my $self = shift;
  my $check_obj = shift;
#  my $hidden_obj = shift;
  my $tmpl = $self->get_row('entry_filter2');

  my $check = $self->_gen_element( 'CHECKBOX', $check_obj );

  return sprintf
    ( $tmpl, 
      $check, 
      $check_obj->get_label() );
  
}

#----------------------------------------------------------------------
sub gen_label_with_text_and_button{
  my $self     = shift;
  my $text_obj = shift;
  my $butt_obj = shift;

  my $tmpl = $self->get_row('entry_filter');
  my $text = $self->_gen_base_form( -type => 'TEXT',
				    -name => $text_obj->get_cgi_name,
				    get_extra( $text_obj ) );

  my $butt = $self->_gen_base_form( -type => 'BUTTON',
				    -name => $butt_obj->get_cgi_name,
				    -value=> $butt_obj->get_value,
				    get_extra( $butt_obj ) );

  return sprintf( $tmpl,
		  '&nbsp;', $text_obj->get_label, $text.$butt );

}

#----------------------------------------------------------------------
sub gen_check_with_text_button_and_radio{
  my $self = shift;
  my @entry_objs = @_;
  my $tmpl = $self->get_row('entry_filter4');

  my $check = $self->_gen_element( 'CHECKBOX', $entry_objs[0] );

  my $text  = $self->_gen_base_form( -type => 'TEXT',
				     -name => $entry_objs[1]->get_cgi_name,
				     get_extra( $entry_objs[1] ) );

  my $butt  = $self->_gen_base_form( -type => 'BUTTON',
				     -name => $entry_objs[2]->get_cgi_name,
				     -value=> $entry_objs[2]->get_value,
				     get_extra( $entry_objs[2] ) );

  my $rad1  = $self->_gen_radio( $entry_objs[3] );

  my $rad2  = $self->_gen_radio( $entry_objs[4] );

  return sprintf( $tmpl, 
		  $check, $entry_objs[1]->get_label.$text.$butt,
		  $rad1, $entry_objs[3]->get_label,
		  $rad2, $entry_objs[4]->get_label  )
    
  
}

#----------------------------------------------------------------------
#
sub gen_check_with_check{
  my $self     = shift;
  my @entry_objs = @_;

  my $tmpl = $self->get_row('entry_select');
  
  my $entry_obj1 = shift @entry_objs;
  my $check1 =  $self->_gen_element( 'CHECKBOX', $entry_obj1 );

  my @checks;
  my @labels;
  foreach my $entry_obj( @entry_objs ){
    push @checks, $self->_gen_element( 'CHECKBOX', $entry_obj );
    push @labels, $entry_obj->get_label;
  }

  # Row 1 - ist 2 checks
  my $html = sprintf( $tmpl, 
		      shift @checks, shift @labels,
		      shift @checks, shift @labels );
  foreach( @checks ){
    $html .= sprintf( $tmpl, 
		      '&nbsp;', '&nbsp;', 
		      $_ , shift @labels );
  }

  return $html;
}


#----------------------------------------------------------------------
# Generates hidden forms
sub gen_hidden_list{
  my $self = shift;
  my @entries = @_;
  my @elements =  map{ $self->_gen_element('HIDDEN2', $_ ) } @entries;
  return join( "\n", @elements );
}

#----------------------------------------------------------------------
# generates a radio button from a FormElement object
sub _gen_radio{
  my $self = shift;
  my $entry = shift;
  return $self->_gen_base_form( -type => 'RADIO',
				-name => $entry->get_cgi_name,
				-value=> $entry->get_value,
				get_extra( $entry ) );
}

#----------------------------------------------------------------------
# generates a select box from a FormElement
sub _gen_select{
  my $self = shift;
  my $entry = shift;
  return $self->_gen_base_form( -type    => 'SELECT',
				-name    => $entry->get_cgi_name,
				-options => [$entry->get_options],
				get_extra( $entry ) );
}

#----------------------------------------------------------------------
sub _gen_text{
  my $self = shift;
  my $entry = shift;
  return $self->_gen_base_form( -type  => 'TEXT',
				-name  => $entry->get_cgi_name,
				-value => $entry->get_value,
				get_extra( $entry ) );
}

#----------------------------------------------------------------------
sub _gen_textarea{
  my $self = shift;
  my $entry = shift;
  my $html =  $self->_gen_base_form( -type  => 'TEXTAREA',
				     -name  => $entry->get_cgi_name,
				     get_extra( $entry ) );
  return $html;
}

#----------------------------------------------------------------------
sub _gen_element{
  my $self  = shift;
  my $type  = shift || confess( 'Need a type' );
  my $entry = shift || confess( 'Need a FormEntry' );
  my %opts = ( -type => uc( $type ) );
  if( my $nm = $entry->get_cgi_name ){ $opts{-name}    = $nm }
  if( my $va = $entry->get_value    ){ $opts{-value}   = $va }
  if( my $op = [$entry->get_options]){ $opts{-options} = $op }
  %opts = ( %opts, get_extra($entry) );
  return $self->_gen_base_form( %opts );
}

#----------------------------------------------------------------------
# Looks through the object and returns a hash of action to java script,
# or some other param  
sub get_extra{
  my $entry = shift;
  my %extra = ();
  if( my $js = $entry->get_cgi_onclick  ){ $extra{-onclick}  = $js }
  if( my $js = $entry->get_cgi_onchange ){ $extra{-onchange} = $js }
  if( my $co = $entry->get_cgi_cols     ){ $extra{-cols}     = $co }
  if( my $ro = $entry->get_cgi_rows     ){ $extra{-rows}     = $ro }
  if( my $sz = $entry->get_cgi_size     ){ $extra{-size}     = $sz }
  if( my $ml = $entry->get_cgi_maxlength){ $extra{-maxlength}= $ml }
  if( my $mu = $entry->get_cgi_multiple ){ $extra{-multiple} = $mu }

  return %extra;
}

#----------------------------------------------------------------------
sub output{
  my $self = shift;
  my %opts = @_;

  # Lame attempt to force correct x-browser rendering!
  my $align = $opts{-align} || 2;
  if( $align == 1 ){
    $self->add_block( 
		     sprintf( 
			     $self->get_row('align1'), 
			     '&nbsp;'x100,) );    
  }
  if( $align == 2 ){
    $self->add_block( 
		     sprintf( 
			     $self->get_row('align2'), 
			     '&nbsp;',
			     '&nbsp;'x50,
			     '&nbsp;',
			     '&nbsp;'x50, ) );
  }

  return $self->SUPER::output();
}

1;

