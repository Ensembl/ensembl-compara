package EnsEMBL::Web::DataUpload;

=head1 NAME

EnsEMBL::Web::DataUpload.pm

=head1 SYNOPSIS

The DataUpload object handles web data uploads.

=head1 DESCRIPTION

 my $param_name = 'upload_file'; # this is the name you gave to your input element, e.g <input type="file" name="upload_file" />
 my $du  = EnsEMBL::Web::DataUpload->new();
 if (defined (my $err = $du->upload_data($param_name))) {
   error("Upload Failed: $du->error");
 }
 my $data = $du->data;

 
 This object uploads data from the specified parameter and 'data' field of the object point to the uploaded data.
 Shortly it will include data parsing and saving them on a server

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use warnings;

use CGI qw( :standard);
use Data::Dumper;

use vars qw( @ISA ); 
@ISA = qw( );

sub new {
  my $class = shift;
  my $self = {
    DATA => '',
    PARSED_DATA => { },
    OBJECT => shift || undef
  };
  bless ($self, $class);
  return $self;



}
=head2 upload_data

 Arg[1]      : upload_data
 Example     : my $err = $du->upload_data
 Description : uploads web data
 Return type : error text

=cut

sub upload_data {
    my $self = shift;
    my ($param_name) = @_;
    my $data;
    delete($self->{_error});

    return $self->error(cgi_error) if defined cgi_error;
    return $self->error("Missing filename") unless defined param($param_name);
    return $self->error("Missing filename") unless (length(param($param_name))> 0);
    
    eval {
	my $fh = upload($param_name);
	return $self->error(qq(Could not open '@{[param($param_name)]}')) unless defined $fh;
	local $/ = undef;
	
	if (param($param_name) =~ /\.gz$/) {
	    use Compress::Zlib;
	    $data = Compress::Zlib::memGunzip(<$fh>);
	} elsif (param($param_name) =~ /\.bz2$/) {
	    require Compress::Bzip2;
	    my $bz = Compress::Bzip2::bzopen($fh, "rb");
	    $bz->bzread($data);
	} else {
	    $data = <$fh>;
	}
	
    };
    
    $self->error($@) if $@;



    $self->{DATA} = $data;
    return $self->error;
}

sub data {
  my $self = shift;
  $self->{DATA} = shift if @_;
  return $self->{DATA};
}

sub error {
  my $self = shift;
  $self->{_error} = shift if @_;
  return $self->{_error};
}

sub species_defs {
    my ($self, $param) = @_;
    return $self->{OBJECT}->species_defs;
}
1;

