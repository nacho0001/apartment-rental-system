document.addEventListener("DOMContentLoaded", function () {

    // ---------- Apartment Search Filter ----------
    const searchInput = document.getElementById("apartmentSearch");
    const apartmentCards = document.querySelectorAll(".apartment-cards .card");

    if (searchInput) {
        searchInput.addEventListener("input", function () {
            const filter = searchInput.value.toLowerCase();
            apartmentCards.forEach(card => {
                const name = card.querySelector("h3").textContent.toLowerCase();
                const location = card.querySelector("p").textContent.toLowerCase();
                card.style.display = (name.includes(filter) || location.includes(filter)) ? "block" : "none";
            });
        });
    }

    // ---------- Navbar Active Link Highlight ----------
    const sections = document.querySelectorAll("section");
    const navLinks = document.querySelectorAll(".navbar a");

    window.addEventListener("scroll", function () {
        let current = "";
        sections.forEach(section => {
            const sectionTop = section.offsetTop - 80;
            const sectionHeight = section.offsetHeight;
            if (window.scrollY >= sectionTop && window.scrollY < sectionTop + sectionHeight) {
                current = section.getAttribute("id");
            }
        });

        navLinks.forEach(link => {
            link.classList.remove("active");
            if (link.getAttribute("href") === `#${current}`) {
                link.classList.add("active");
            }
        });
    });

    // ---------- Login Form Toggle ----------
    const loginBtn = document.querySelector(".login-btn");
    const loginForm = document.getElementById("login");

    if (loginBtn && loginForm) {
        loginBtn.addEventListener("click", function(e) {
            e.preventDefault();
            if (loginForm.style.display === "none") {
                loginForm.style.display = "block";
                loginForm.scrollIntoView({ behavior: "smooth" });
            } else {
                loginForm.style.display = "none";
            }
        });
    }
});