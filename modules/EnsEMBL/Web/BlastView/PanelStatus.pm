#----------------------------------------------------------------------
#
#
#
#----------------------------------------------------------------------

package EnsEMBL::Web::BlastView::PanelStatus;

use strict;
use CGI;
use HTML::Template;

use EnsEMBL::Web::BlastView::Panel;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::BlastView::Panel);

my %cells;


# Horizontal padding (VDARK_BG_COLOR)
$cells{H} = qq(
    <TD height=1 width=10 bgcolor="<TMPL_VAR VDARK_BG_COLOR>" colspan=1
    ><IMG src="/img/blank.gif" height=1 width=5 /></TD>);

# Small Horizontal padding (VDARK_BG_COLOR)
$cells{h} = qq(
    <TD height=1 width=5 bgcolor='<TMPL_VAR VDARK_BG_COLOR>' colspan=1
    ><IMG src='/img/blank.gif' height=1 width=5 /></TD>);

# Vertical padding (VDARK_BG_COLOR)
$cells{V} = qq(
    <TD height=5 width=1 bgcolor='<TMPL_VAR VDARK_BG_COLOR>' colspan=1
    ><IMG src='/img/blank.gif' height=5 width=1 /></TD>);
$cells{v} = qq(
    <TD height=5 width=1 bgcolor='<TMPL_VAR VDARK_BG_COLOR>' colspan=1
    ><IMG src='/img/blank.gif' height=5 width=1 /></TD>);

# 1-pixel border
$cells{_}= qq(
    <TD height=1 width=1 bgcolor='<TMPL_VAR BORDER_COLOR>' colspan=1
    ><IMG src='/img/blank.gif' height=1 width=1 /></TD>);

# Status header cell
$cells{S}= qq(
    <TD class='status_panel_head' colspan=1 nowrap align='center' valign='bottom'
    >%s</TD>);


# Bold text cell
$cells{T}= qq(
    <TD class='status_block_head' colspan=1
    >%s</TD>);

# Normal text cell
$cells{t}= qq(
    <TD class='status_entry' colspan=1
    >%s</TD>);

# Big bullet
$cells{B}= qq(
    <TD class='status_entry' colspan=1 width=12 height=12 valign='middle'
    ><IMG src='/img/blastview/bullet1.gif' height=12 width=12 /></TD>);

# Small bullet
$cells{b}= qq(
    <TD class='status_entry' colspan=1 width=7 height=7 valign='middle'
    ><IMG src='/img/blastview/bullet2.gif' height=7 width=7 /></TD>);

# Warn image
$cells{W} = qq(
    <TD height=12 width=12 colspan=1
    ><IMG src='/img/blastview/warn.gif' height=12 width=12 /></TD>);

# Info image
$cells{I} = qq(
    <TD height=12 width=12 colspan=1
    ><IMG src='/img/blastview/info.gif' height=12 width=12 /></TD>);

# Warn text
$cells{w} = qq(
    <TD height=20 width=20 colspan=1 class='status_warning'
    >%s</TD>);

# Info text
$cells{i} = qq(
    <TD colspan=1 class='status_entry'
    ><I><SMALL>%s</SMALL></I></TD>);


my %rows;

# Panel padding
$rows{panel_padding} = 'HVVVVVH';

# Panel header
$rows{panel_header } = 'HSSSSSH';

$rows{panel_header2} = 'HSSSSSH';

# Block header
$rows{block_header } = 'HBhTTTH';

# Entry padding
$rows{entry_padding } = 'HvvvvvH';

# Entry
$rows{entry_header } = 'HhhbhtH';

# Number summary
$rows{entry_footer } = 'HIhiiiH';

# Warning
$rows{warning }      = 'HWhwwwH';

# Info
$rows{info    }      = 'HIhiiiH';

$rows{align   }      = 'HththtH';

my $panel = EnsEMBL::Web::BlastView::Panel->new({ rowdefs=>\%rows, celldefs=>\%cells});


#----------------------------------------------------------------------
# Creates a new PanelStatus object
sub new{

  my $class = shift;
  my $cgi   = shift;
  if( ref( $cgi ) ne 'CGI' ){ die( 'This function requires a CGI object' )};

  my $self = {
	      CGI       => $cgi,
	      panel     => $panel,
	      avail     => 'on',
	      data      => [],
	      pointers  => { block => 0,
			     entry => 0,
			     form  => 0 },

	      panel_top_row     => $panel->get_row('panel_padding'),
	      panel_base_row    => $panel->get_row('panel_padding'),
	      panel_padding_row => $panel->get_row('panel_padding'),

	      block_top_row     => $panel->get_row('panel_padding'),
	      block_base_row    => $panel->get_row('panel_padding'),
	      block_padding_row => $panel->get_row('entry_padding'),

	      entry_padding_row => $panel->get_row('entry_padding'),
	      entry_top_row     => $panel->get_row('entry_padding'),
	      entry_base_row    => $panel->get_row('entry_padding'),

	      html_tmpl => '',
	     };

  bless $self, $class;

  return $self;
}

#----------------------------------------------------------------------
# Adds a warning row to the panel
#sub add_warning{
#  my $self = shift;
#  my $meta = shift;
#  $self->add_block( $self->get_row('warning') );
#  return 1;
#}

#----------------------------------------------------------------------
# Adds a info row to the panel
sub add_info{
  my $self = shift;
  my $meta = shift;
  $self->add_block( $self->get_row('info') );
  return 1;
}

#----------------------------------------------------------------------
# 
sub add_panel_button{
  my $self = shift;
  
  my @button_meta = @_;
  my $html;

  my $i = 0;
  while( $i < @button_meta ){

    my @buttons = ();
    
    foreach my $meta( $button_meta[$i], $button_meta[$i+1] ){
      my $button;
      if( $meta->{NAME} ){
	$button = $self->_gen_base_form( -type =>'image',
					 -name =>$meta->{NAME},
					 -value=>$meta->{VALUE}, 
					 -src  =>$meta->{SRC} );
      }
      elsif( $meta->{HREF} ){
	my $tmpl = qq(<A HREF="%s" %s><IMG src="%s" border=0 %s /></A>);
	my $ahr_extra = '';
	my $img_extra = '';
	if( $meta->{TARGET} ){ $ahr_extra.=" target='$meta->{TARGET}'"}
	if( $meta->{CLASS}  ){ $ahr_extra.=" class='$meta->{CLASS}'"}
	if( $meta->{HEIGHT} ){ $img_extra.=" height='$meta->{HEIGHT}'"} 
	if( $meta->{WIDTH}  ){ $img_extra.=" width ='$meta->{WIDTH}'"}
	$button = sprintf( $tmpl, 
			   $meta->{HREF}, $ahr_extra,
			   $meta->{SRC},  $img_extra );
      }
      else{
	my $tmpl = qq(<IMG src="%s" border=0 %s />);
	my $extra = '';
	if( $meta->{HEIGHT} ){ $extra.="height='$meta->{HEIGHT}'"} 
	if( $meta->{WIDTH}  ){ $extra.="width ='$meta->{WIDTH}'"} 
	if( $meta->{TARGET} ){ $extra.=" target='$meta->{TARGET}'"}
	$button = sprintf( $tmpl, $meta->{SRC}, $extra );
      }
      push @buttons, $button;
      $i++;
    }
    $html .= sprintf( $self->get_row('panel_header'),
		      join( 
			   #'&nbsp;',
			   '<IMG src="/img/blank.gif" height=1 width=10 />',
			    @buttons ) );
  }
  $self->add_block( $html );
  return 1;
}

#----------------------------------------------------------------------
#
sub output{
  my $self = shift;
  $self->add_block( sprintf( $self->get_row('align'), '','','&nbsp;'x20 ) );
  return $self->SUPER::output();
}

1;
