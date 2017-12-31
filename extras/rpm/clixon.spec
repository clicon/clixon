%{!?_topdir: %define _topdir %(pwd)}
%{!?cligen_prefix: %define cligen_prefix %{_prefix}}

Name: clixon
Version: %{_version}
Release: %{_release}
Summary: The XML-based command line processing tool CLIXON
Group: System Environment/Libraries
License: ASL 2.0 or GPLv2
URL: http://www.clicon.org
AutoReq: no
BuildRequires: flex, bison
Requires: cligen, fcgi

# Sometimes developers want to build it without installing cligen but passing
# path using --with-cligen and pointing it to cligen buildroot. Use %{developer}
# macro for these cases
%if 0%{!?developer:1}
BuildRequires: cligen
%endif

Source: %{name}-%{version}-%{release}.tar.xz

%description
The XML-based command line processing tool CLIXON.

%package devel
Summary: CLIXON header files
Group: Development/Libraries
Requires: clixon

%description devel
This package contains header files for CLIXON.

%prep
%setup

%build
%configure --with-cligen=%{cligen_prefix} --without-keyvalue
make

%install
make DESTDIR=${RPM_BUILD_ROOT} install install-include

%files
%{_libdir}/*
%{_bindir}/*
%{_sbindir}/*
#%{_sysconfdir}/*
%{_datadir}/%{name}/*
/www-data/clixon_restconf

%files devel
%{_includedir}/%{name}/*

%clean

%post
/sbin/ldconfig

caps="cap_setuid,cap_fowner,cap_chown,cap_dac_override"
caps="${caps},cap_kill,cap_net_admin,cap_net_bind_service"
caps="${caps},cap_net_broadcast,cap_net_raw"

if [ -x /usr/sbin/setcap ]; then
	/usr/sbin/setcap ${caps}=ep %{_bindir}/clixon_cli
	/usr/sbin/setcap ${caps}=ep %{_bindir}/clixon_netconf
	/usr/sbin/setcap ${caps}=ep %{_sbindir}/clixon_backend
fi

%postun
/sbin/ldconfig
