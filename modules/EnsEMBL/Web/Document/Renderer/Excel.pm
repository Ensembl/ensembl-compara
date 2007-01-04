package EnsEMBL::Web::Document::Renderer::Excel;

use strict;
use IO::File;
use Spreadsheet::WriteExcel;

sub new{
  my $class = shift;
  my $filename = shift;

 my $fh = new IO::File;
  my $self;
  if( $fh->open( ">$filename") ) {
    tie *XLS => 'Apache';
    binmod (*XLS);
    my $fh   = Spreadsheet::WriteExcel->new($filename);
    die "Problems creating new Excel file: $!" unless defined $fh;
    $self = { 'file' => $fh, 'row' => 0, 'col' => 0 };
  } else {
    $self = { 'file' => undef };
  }
  bless($self, $class);
  return $self;
}


sub valid  { return $_[0]->{'file'}; }
sub printf { my $self = shift; my $FH = $self->{'file'}; printf $FH @_ if $FH; }
sub print  { my $self = shift; my $FH = $self->{'file'}; print  $FH @_ if $FH;}

sub close  { my $FH = $_[0]->{'file'}; close $FH; $_[0]->{'file'} = undef; }
sub DESTROY { my $FH = $_[0]->{'file'}; close $FH; }

sub write_cell {
  my $self = shift;;
  $self->write_sheet( $self->{'row'}, $self->{'col'}, @_ );
}

sub print {
  my $self = shift;
  $self->write_cell(@_);
  $self->next_row;
}
sub next_row {
  my $self = shift;
  $self->{'row'}++;
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
  my $worksheet = $self->worksheet;
  return unless $worksheet;
  $worksheet->write($row, $col, $info, $format) ==0 || die "ERROR: Couldn't write to
page";
}

sub workbook {
  my $self = shift;
  return $self->{'file'};
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
  my $workbook = $self->filehandle;
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
  my $workbook = $self->filehandle;
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
