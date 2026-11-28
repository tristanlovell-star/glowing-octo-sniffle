import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Styles the screen a child sees when opening a blocked app or website during
/// school hours, so it matches the black-and-amber Schooltime look.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let amber = UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        schooltime(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        schooltime(name: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        schooltime(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        schooltime(name: webDomain.domain ?? category.localizedDisplayName)
    }

    private func schooltime(name: String?) -> ShieldConfiguration {
        let context = SharedStore.loadContext()
        let what = name.map { "\($0) is" } ?? "This app is"
        let subtitle = "\(what) blocked during Schooltime.\n\(context.statusDetail().capitalizedFirst)"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "graduationcap.circle.fill")?
                .withTintColor(amber, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "Schooltime", color: amber),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: amber,
            secondaryButtonLabel: nil
        )
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
