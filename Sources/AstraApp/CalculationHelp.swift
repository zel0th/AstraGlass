import Foundation

/// Short descriptions of Astrolog's numbered house systems; see its bundled manual.
func houseSystemDescription(_ id: Int) -> String {
    switch id {
    case 0: return L10n.text("Плацидус делит суточные дуги по времени. Дома неравны; первый начинается на ASC, десятый — на MC. В полярных широтах движок может перейти к Порфирию.", "Placidus divides diurnal arcs by time. Houses are unequal, with ASC and MC at the first and tenth cusps. At polar latitudes the engine may use Porphyry.")
    case 1: return L10n.text("Кох использует время восхождения и широту места рождения. ASC и MC задают угловые дома; в полярных широтах возможен переход к Порфирию.", "Koch uses rising times and birthplace latitude. ASC and MC anchor the angular houses; polar calculations may fall back to Porphyry.")
    case 2: return L10n.text("Двенадцать домов по 30°, начиная с Асцендента. MC не обязательно совпадает с началом десятого дома.", "Twelve 30° houses starting at the Ascendant. MC need not coincide with the tenth cusp.")
    case 3: return L10n.text("Кампано делит первый вертикал на равные части и проецирует их на эклиптику. Дома обычно имеют разную длину.", "Campanus divides the prime vertical equally and projects it onto the ecliptic. The resulting houses are usually unequal.")
    case 4: return L10n.text("Меридианная система делит небесный экватор. MC задаёт десятый дом; первый куспид может отличаться от ASC. Не зависит от широты.", "The Meridian system divides the celestial equator. MC anchors the tenth cusp; the first can differ from ASC. It is independent of latitude.")
    case 5: return L10n.text("Региомонтан делит небесный экватор на равные дуги, проецируя их через северную и южную точки горизонта на эклиптику.", "Regiomontanus divides the celestial equator into equal arcs and projects them through the horizon's north and south points onto the ecliptic.")
    case 6: return L10n.text("Порфирий делит каждый из четырёх секторов между ASC, MC и противоположными точками на три равные части.", "Porphyry trisects each of the four quadrants between ASC, MC and their opposite points.")
    case 7: return L10n.text("Морин — система на основе равного деления экватора. Она не зависит от широты; ASC и MC могут не совпадать с первым и десятым куспидами.", "Morin is based on equal divisions of the equator. It is independent of latitude; ASC and MC may differ from the first and tenth cusps.")
    case 8: return L10n.text("Топоцентрическая система Полиха—Пейджа учитывает местный горизонт. Часто близка к Плацидусу, но использует другой способ построения куспидов.", "The Polich–Page Topocentric system uses the local horizon. It often resembles Placidus but constructs intermediate cusps differently.")
    case 9: return L10n.text("Алькабициус — традиционная квадрантная система. Угловые дома опираются на ASC и MC, промежуточные определяются делением дуг восхождения.", "Alcabitius is a traditional quadrant system. ASC and MC anchor the angular houses; intermediate cusps derive from divisions of rising arcs.")
    case 10: return L10n.text("Крусинский — квадрантная система с собственным геометрическим построением промежуточных куспидов. ASC и MC остаются опорными точками.", "Krusinski is a quadrant system with its own geometric construction of intermediate cusps. ASC and MC remain its anchors.")
    case 11: return L10n.text("Равные дома по 30°: MC задаёт начало десятого дома. Первый куспид не обязательно совпадает с ASC.", "Equal 30° houses with MC at the tenth cusp. The first cusp need not coincide with ASC.")
    case 12, 13: return L10n.text(id == 12 ? "Пуллен S.Ratio плавно распределяет размеры домов между ASC и MC по соотношению длин секторов." : "Пуллен S.Delta плавно распределяет размеры домов между ASC и MC по разности длин секторов.", id == 12 ? "Pullen S.Ratio smoothly distributes house sizes between ASC and MC using quadrant size ratios." : "Pullen S.Delta smoothly distributes house sizes between ASC and MC using quadrant size differences.")
    case 14: return L10n.text("Знак, содержащий ASC, целиком становится первым домом. Каждый следующий знак — следующий дом; куспиды всегда на 0° знаков.", "The entire sign containing ASC becomes the first house. Each following sign is the next house; cusps are always at 0° of signs.")
    case 15: return L10n.text("Ведическая (Велоу): двенадцать домов по 30°, ASC находится в середине первого дома. Выбор этой системы сам по себе не включает сидерический зодиак.", "Vedic (Vehlow): twelve 30° houses with ASC in the middle of the first house. This choice does not itself enable the sidereal zodiac.")
    case 16: return L10n.text("Шрипати использует деление Порфирия, но сдвигает границы к серединам предшествующих домов. Угловые точки оказываются центрами домов.", "Sripati uses Porphyry divisions but moves boundaries to the midpoints of preceding houses. Angular points become house centers.")
    case 17: return L10n.text("Горизонтальная система делит местный горизонт и проецирует деления через зенит и надир. MC задаёт десятый дом, Вертекс — седьмой; первый куспид отличается от ASC.", "The Horizon system divides the local horizon and projects through zenith and nadir. MC anchors the tenth house, Vertex the seventh; the first cusp differs from ASC.")
    case 18: return L10n.text("APC — система астрологических плоскостей. Промежуточные противоположные куспиды могут находиться не строго через 180°.", "APC uses astrological planes. Opposing intermediate cusps are not necessarily 180° apart.")
    case 19: return L10n.text("Картер: первый дом начинается на ASC. Промежуточные куспиды строятся по экватору, поэтому MC не обязательно является началом десятого дома.", "Carter starts the first house at ASC. Intermediate cusps use the equator, so MC need not be the tenth cusp.")
    case 20: return L10n.text("Sunshine учитывает склонение Солнца. Противоположные промежуточные дома могут быть несимметричны; в полярных широтах возможны дома нулевой длины.", "Sunshine uses the Sun's declination. Opposing intermediate houses may be asymmetric; polar latitudes can produce zero-width houses.")
    case 21: return L10n.text("Савар A — пространственное деление с использованием первого вертикала и параллелей склонения. Его куспиды отличаются от системы Кампано.", "Savard A divides space using the prime vertical and declination parallels. Its cusps differ from Campanus.")
    case 22: return L10n.text("Фиксированная сетка: первый сектор начинается с 0° Овна, остальные идут по 30°. Она не описывает местные астрологические дома.", "A fixed grid: the first sector starts at 0° Aries and each spans 30°. It does not describe local astrological houses.")
    case 23: return L10n.text("Целые знаки с опорой на MC: знак MC становится десятым домом. Первый дом не обязательно содержит ASC.", "Whole signs anchored to MC: the MC sign becomes the tenth house. The first house need not contain ASC.")
    case 24: return L10n.text("Дома по 30°, MC находится в середине десятого дома.", "Thirty-degree houses with MC in the middle of the tenth house.")
    case 25...27: return L10n.text("Сбалансированный вариант использует совместную опору ASC и MC. ", "The balanced variant uses ASC and MC together as its reference. ") + variantDescription((id - 25))
    case 28...30: return L10n.text("Опора — восточная точка (EP), экваториальный Асцендент; вместо обычного ASC. ", "Anchored to the East Point (EP), the equatorial Ascendant, instead of the usual ASC. ") + variantDescription(id - 28)
    case 31...33: return L10n.text("Опора — Антивертекс, точка напротив Вертекса, вместо ASC. ", "Anchored to the Antivertex, opposite the Vertex, instead of ASC. ") + variantDescription(id - 31)
    case 34...39:
        let method = id < 36 ? L10n.text("Порфирий", "Porphyry") : (id < 38 ? "Pullen S.Ratio" : "Pullen S.Delta")
        let point = id % 2 == 0 ? L10n.text("восточная точка EP", "East Point EP") : L10n.text("Антивертекс", "Antivertex")
        return L10n.text("\(method): опорные точки — MC и \(point) вместо ASC.", "\(method): anchored to MC and \(point) instead of ASC.")
    default: return ""
    }
}

private func variantDescription(_ variant: Int) -> String {
    switch variant {
    case 0: return L10n.text("Равные дома по 30° от опорной точки.", "Equal 30° houses starting at the reference point.")
    case 1: return L10n.text("Целые знаки, начиная со знака опорной точки.", "Whole-sign houses starting with the reference point's sign.")
    default: return L10n.text("Равные дома по 30°, опорная точка в центре первого дома.", "Equal 30° houses with the reference point at the first house's center.")
    }
}

func zodiacDescription(sidereal: Bool) -> String {
    if sidereal {
        return L10n.text("Сидерический зодиак учитывает прецессию: от тропических долгот вычитается айанамша (здесь Фаган—Брэдли). Это 12 равных знаков по 30°, а не границы астрономических созвездий.", "The sidereal zodiac accounts for precession by subtracting an ayanamsha (Fagan–Bradley here) from tropical longitudes. It still uses twelve equal 30° signs, not astronomical constellation boundaries.")
    }
    return L10n.text("Тропический зодиак отсчитывается от точки весеннего равноденствия. Сидерический вариант смещает начало знаков относительно неё, поэтому положения по знакам могут измениться.", "The tropical zodiac starts at the vernal equinox. The sidereal option shifts the signs relative to it, so sign placements can change.")
}
