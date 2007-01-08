package EnsEMBL::Web::Document::Renderer::Excel;

use strict;
use Spreadsheet::WriteExcel;
use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Root);

sub new{
  my $class = shift;

# my $fh = new IO::File;
  my $self ={ 'row' => 0, 'sheet' => -1, 'col' => 0 };
  bless($self, $class);
  my $filename = $self->species_defs->ENSEMBL_TMP_DIR.'/'.$self->temp_file_create( 'xls-temp' ); 
  $self->{'filename'} = $filename;
  my $workbook   = Spreadsheet::WriteExcel->new( $filename );
  $self->{'workbook'} = $workbook;
  return $self;
}

sub species_defs {
  my $self = shift;
  $self->{'species_defs'} ||= $ENSEMBL_WEB_REGISTRY->species_defs;
  return $self->{'species_defs'};
}

sub raw_content {
  my $self = shift;
warn "RETURNING CONTENT";
  open FH, $self->{'filename'};
  local $/ = undef;
  my $content = <FH>;
  close FH;
#  unlink $self->{'filename'};
  warn $self->{'filename'};
  return $content;
}

sub valid  { return $_[0]->{'workbook'}; }
#sub printf { my $self = shift; my $FH = $self->{'workbook'}; printf $FH @_ if $FH; }
#sub print  { my $self = shift; my $FH = $self->{'workbook'}; print  $FH @_ if $FH;}

sub printf {
  my $self = shift;
  my $cols = shift;
  my $format = shift;
  $self->next_row if $self->{'col'};
  my $worksheet = $self->workbook->sheets($self->{'sheet'});
  $worksheet->merge_range( $self->{'row'},0,$self->{'row'},$cols-1,sprintf(@_),$format);
  $self->next_row;
}
 
sub print {
  my $self = shift;
  my $cols = shift;
  my $format = shift;
  $self->next_row if $self->{'col'};
  my $worksheet = $self->workbook->sheets($self->{'sheet'});
  $worksheet->merge_range( $self->{'row'}, 0, $self->{'row'}, $cols-1, join( '',@_) , $format);
  $self->next_row;
}
 
sub close  { 
  my $self = shift;
  return unless $self->{'workbook'};
warn "CLOSING WORKBOOK..";
  $self->{'workbook'}->close;
  $self->{'workbook'} = undef;
}
sub DESTROY {
  my $self = shift;
  $self->close;
}

sub write_cell {
  my $self = shift;;
  $self->write_sheet( $self->{'row'}, $self->{'col'}, @_ );
  $self->{'col'}++;
}

sub next_row {
  my $self = shift;
  $self->{'row'}++;
  $self->{'col'}=0;
}

sub next_sheet {
  my $self = shift;
  my $name = shift;
  $self->{'sheet'}++;
  $self->workbook->add_worksheet( $name );
  $self->{'row'}=0;
  $self->{'col'}=0;
}
sub write_sheet {

  ### Arg[1]      : row to print to
  ### Arg[2]      : column (or start column if you pass an array of data)
  ###  Arg[3]      : string or array ref of data (array ref, one value per cell)
  ### Arg[4]      : format (optional)
  ### Example     : $output->write_sheet(2, 0, \@my_friends, $bold_format)
  ### Description : Addes worksheet to excel workbook (filehandle)
  ### Returns none

  my $self   = shift;
  my $row    = shift || 0;
  my $col    = shift || 0;
  my $info   = shift;
  my $format = shift;
  my $worksheet = $self->workbook->sheets($self->{'sheet'});
  return unless $worksheet;
  warn $worksheet->write($row, $col, $info, $format);
}

sub workbook {
  my $self = shift;
  return $self->{'workbook'};
}


sub worksheet {

  ### a
  ### Arg (optional): new worksheet name
  ### Example     : $output->worksheet
  ### Description : Getter / Adds worksheet to excel workbook (filehandle)

  my $self = shift;
  my $workbook = $self->workbook;

  if (@_) {
    my $worksheet = $workbook->add_worksheet(shift);
    $self->{worksheet} = $worksheet;
  }
  return $self->{worksheet};
}

sub new_format {

  ### Example : my $bold = $output->new_format
  ### Description : creates a new format
  ### Returns $format

  my $self = shift;
  my $workbook = $self->workbook;
warn "NF $workbook";
  return unless $workbook;
  return $workbook->add_format();
}


sub bold {

  ### Arg1      : format object (created by $self->new_format)
  ### Arg2      : turn bold on or off (i.e. 1 or 0)
  ### Example     : my $bold = $output->bold($format, 1);
  ### Description : adds bold to format
  ### Returns $format

  my $self   = shift;
  my $format = shift;
  $format->set_bold(shift);
  return $format;
}

sub italic {

  ### Arg1      : format object (created by $self->new_format)
  ### Arg2      : turn italic on or off (i.e. 1 or 0)
  ### Example     : my $italic = $output->italic($format, 1);
  ### Description : adds italic to format
  ### Returns $format

  my $self   = shift;
  my $format = shift;
  $format->set_italic(shift);
  return $format;
}

sub align {

  ### Arg1      : format object (created by $self->new_format)
  ### Arg2      : position (i.e. center, right, left)
  ### Example     : $output->align($format, $position);
  ### Description : specifies the alignment in the format
  ### Returns $format

  my $self   = shift;
  my $format = shift;
  $format->set_align( shift );
  return $format;
}



sub bg_color {

  ### Arg1      : format object (created by $self->new_format)
  ### Arg2      : index for the color e.g. 9 or the return from $self->custom_color("#fffbbb")
  ### Example     : $output->bg_color($format, 9);
  ### Description : adds bold to format
  ### Returns $format

  my $self   = shift;
  my $format = shift;
  $format->set_bg_color( shift );
  return $format;
}


sub custom_color {

  ### Arg     : color
  ### Example     : $output->custom_color(#FF6600)
  ### Description : Returns an index for a new custom color
  ### Returns index for the color

  my $self   = shift;
  my $color = shift;
  my $workbook = $self->workbook;
  return unless $workbook;

  my $number = $self->get_color_number($color);
  return 0 unless $number;
  return $workbook->set_custom_color($number, $color);
}



sub get_color_number {

  ### Example :  my $number = $self->get_color_number;
  ### To create a custom color in excel you need a color index.
  ### This number must be in the following :[19, 21, 24..52, 54..63];
  ### If this colour has been used before, return that index,
  ### otherwise use this method to return the next available number
  ### Returns number for the color

  my $self  = shift;
  my $color = shift;

  unless ( $self->{colors} ) {
    $self->{colors} = [19, 21, 24..52, 54..63];
  }

  unless ( $self->{defined_colors}{$color} ) {
    my $color_number = shift @{$self->{colors} };
    $self->{defined_colors}{$color} = $color_number;
  }

  return $self->{defined_colors}{$color};
}


1;
