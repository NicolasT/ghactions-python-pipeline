%global srcname ghactions-python-pipeline
%global forgeurl https://github.com/NicolasT/%{srcname}/

Version:        0.1.0

%forgemeta

Name:           %{srcname}
Release:        1%{?dist}
Summary:        Test repository for a GitHub Actions-based build/test/release pipeline or a Python project.
License:        GPL 3.0
URL:            %{forgeurl}
Source0:        %{forgesource}

BuildArch:      noarch

%{?python_enable_dependency_generator}

BuildRequires:  python3-rpm-macros
BuildRequires:  python%{python3_pkgversion}-devel

%description
Test repository for a GitHub Actions-based build/test/release pipeline or a Python project.

%prep
%forgeautosetup

%build
%py3_build

%install
%py3_install

%check
true

%files
%license LICENSE
%doc README.md
%{python3_sitelib}/ghactions_python_pipeline
%{python3_sitelib}/ghactions_python_pipeline-%{version}-py%{python3_version}.egg-info/
%{_bindir}/ghactions-python-pipeline

%changelog
* Sun Nov 28 2021 Nicolas Trangez <ikke@nicolast.be> - 0.1.0-1
- Initial package
